"""Disparos, impactos y explosiones de alta calidad para WARMACHINE, sintetizados offline.

Reemplazan a los sonidos 8-bit de `core/sfx.gd`: Sfx busca `assets/audio/sfx/<nombre>_<n>.wav` y, si existen,
los usa en vez de su receta (con variantes al azar sin repetir). Para cambiar un sonido por audio real basta con
pisar esos archivos (o borrar las variantes y dejar una sola).

Uso (desde la raíz del proyecto):  python art_source/audio/synth_guns.py [nombre ...]
Después: Godot --headless --path . --import

Cada disparo se arma por capas, como un disparo grabado:
- chasquido: ráfaga de ruido de 1-2 ms (la onda de la boca del cañón);
- explosión: ruido en tres bandas, la aguda se apaga primero y la grave al final;
- golpe: seno que cae de tono (el peso en el pecho);
- mecánica: clics y resonancias metálicas (corredera, cerrojo, bomba);
- espacio: eco de los edificios (slapback) y reverb difusa por convolución, más oscura cuanto más tarde.
"""
import os
import sys
import wave

import numpy as np
from scipy.signal import butter, fftconvolve, sosfilt

SR = 44100
OUT_DIR = os.path.join("assets", "audio", "sfx")
VARIANTS = 3


# ------------------------------------------------------------------------------------------------
# Piezas
# ------------------------------------------------------------------------------------------------

class Synth:
    def __init__(self, seed, jitter=0.06):
        self.rng = np.random.default_rng(seed)
        self.jitter = jitter

    def j(self, value, amount=1.0):
        """Variación chica por variante para que dos tiros seguidos no suenen idénticos."""
        return value * (1.0 + self.rng.uniform(-self.jitter, self.jitter) * amount)

    def noise(self, n):
        return self.rng.uniform(-1.0, 1.0, n)

    def filt(self, x, kind, f, order=2):
        nyq = SR * 0.5 - 100.0
        if kind == "bp":
            lo, hi = f
            sos = butter(order, [max(20.0, lo), min(nyq, hi)], "bandpass", fs=SR, output="sos")
        elif kind == "lp":
            sos = butter(order, min(nyq, f), "lowpass", fs=SR, output="sos")
        else:
            sos = butter(order, max(20.0, f), "highpass", fs=SR, output="sos")
        return sosfilt(sos, x)

    @staticmethod
    def env(n, tau, attack=0.0004, hold=0.0):
        t = np.arange(n) / SR
        e = np.exp(-np.maximum(0.0, t - hold) / max(tau, 1e-5))
        if attack > 0.0:
            e *= np.clip(t / attack, 0.0, 1.0)
        return e

    def burst(self, dur, tau, kind, f, gain, attack=0.0004, hold=0.0, order=2):
        n = int(dur * SR)
        return self.filt(self.noise(n), kind, f, order) * self.env(n, self.j(tau), attack, hold) * gain

    def thump(self, dur, f0, f1, tau, gain):
        n = int(dur * SR)
        t = np.arange(n) / SR
        f0, f1 = self.j(f0, 0.6), self.j(f1, 0.6)
        freq = f1 + (f0 - f1) * np.exp(-t / (tau * 0.45))
        phase = 2.0 * np.pi * np.cumsum(freq) / SR
        return np.sin(phase) * self.env(n, self.j(tau), 0.0006) * gain

    def ring(self, freqs, tau, gain, dur=None):
        dur = dur or tau * 7.0
        n = int(dur * SR)
        t = np.arange(n) / SR
        out = np.zeros(n)
        for i, f in enumerate(freqs):
            out += np.sin(2.0 * np.pi * self.j(f, 0.4) * t + self.rng.uniform(0, 6.28)) / (1.0 + i * 0.6)
        return out * self.env(n, self.j(tau), 0.0003) * gain

    def crackle(self, dur, density, band, gain, start_tau=0.4):
        """Chasquidos sueltos (escombros, brasas): impulsos al azar que se ralean con el tiempo."""
        n = int(dur * SR)
        t = np.arange(n) / SR
        prob = density / SR * np.exp(-t / start_tau)
        imp = (self.rng.random(n) < prob) * self.rng.uniform(-1.0, 1.0, n)
        return self.filt(fftconvolve(imp, np.exp(-np.arange(int(0.004 * SR)) / (0.0008 * SR)))[:n], "bp", band) * gain


def place(buf, x, t0):
    i = int(t0 * SR)
    if i >= len(buf):
        return
    end = min(len(buf), i + len(x))
    buf[i:end] += x[: end - i]


# ------------------------------------------------------------------------------------------------
# Espacio y master
# ------------------------------------------------------------------------------------------------

def reverb_ir(s, rt60, bright=5500.0, dark=900.0, dark_after=0.08, early=()):
    n = int(rt60 * 1.1 * SR)
    t = np.arange(n) / SR
    decay = np.exp(-6.91 * t / rt60)
    raw = s.noise(n) * decay
    a = np.exp(-t / dark_after)
    ir = s.filt(raw, "lp", bright) * a + s.filt(raw, "lp", dark) * (1.0 - a)
    ir[: int(0.006 * SR)] *= np.linspace(0.0, 1.0, int(0.006 * SR))  # predelay suave
    for ms, g in early:
        idx = int(s.j(ms, 0.5) * 0.001 * SR)
        if idx < n:
            ir[idx] += g * (1.0 if s.rng.random() > 0.5 else -1.0)
    return ir / (np.sqrt(np.sum(ir ** 2)) + 1e-9)


def slap(s, dry, delay, gain, lp=2400.0):
    out = np.zeros_like(dry)
    d = int(s.j(delay, 0.4) * SR)
    if d < len(dry):
        out[d:] = s.filt(dry, "lp", lp)[: len(dry) - d] * gain
    return out


def master(s, dry, *, rt60=0.8, wet=0.3, slaps=((0.11, 0.2),), drive=2.2, peak=0.89,
           room_bright=5500.0, dry_lp=None, early=((11, 0.5), (19, 0.35), (31, 0.25), (47, 0.15))):
    if dry_lp:
        dry = s.filt(dry, "lp", dry_lp)
    # Saturación suave: aplana el pico y le da cuerpo, como un micrófono que se pasa
    x = np.tanh(dry * drive) / np.tanh(drive)
    out = x.copy()
    for delay, g in slaps:
        out += slap(s, x, delay, g)
    if wet > 0.0:
        ir = reverb_ir(s, rt60, bright=room_bright, early=early)
        out += fftconvolve(x, ir)[: len(x)] * wet * 1.2
    out = s.filt(out, "hp", 35.0)
    # Recorte del silencio del final y fundido para no dejar un clic
    level = np.abs(out)
    above = np.nonzero(level > np.max(level) * 0.0015)[0]
    end = min(len(out), (above[-1] if len(above) else len(out) - 1) + int(0.02 * SR))
    out = out[:end]
    fade = min(len(out), int(0.025 * SR))
    out[-fade:] *= np.linspace(1.0, 0.0, fade)
    return out / (np.max(np.abs(out)) + 1e-9) * peak


def buf(seconds):
    return np.zeros(int(seconds * SR))


# ------------------------------------------------------------------------------------------------
# Recetas
# ------------------------------------------------------------------------------------------------

def gun_core(s, b, *, crack=1.0, crack_tau=0.0012, hi=0.7, hi_tau=0.010, hi_band=(2500, 9500),
             mid=0.9, mid_tau=0.028, mid_band=(380, 2600), low=0.8, low_tau=0.05, low_lp=420,
             th=0.9, th_f=(180, 55), th_tau=0.04):
    place(b, s.burst(0.012, crack_tau, "hp", 1800, crack, attack=0.00005), 0.0)
    place(b, s.burst(hi_tau * 8, hi_tau, "bp", hi_band, hi, attack=0.0002), 0.0)
    place(b, s.burst(mid_tau * 7, mid_tau, "bp", mid_band, mid, attack=0.0005), 0.0)
    place(b, s.burst(low_tau * 6, low_tau, "lp", low_lp, low, attack=0.001), 0.0)
    place(b, s.thump(th_tau * 6, th_f[0], th_f[1], th_tau, th), 0.0)


def shot_pistol(s):
    b = buf(1.0)
    gun_core(s, b)
    # corredera: atrás y adelante
    place(b, s.burst(0.012, 0.0018, "bp", (3000, 9000), 0.28), s.j(0.026))
    place(b, s.ring([3100, 4700, 6900], 0.006, 0.10), s.j(0.026))
    place(b, s.burst(0.012, 0.0015, "bp", (2500, 8000), 0.2), s.j(0.058))
    return master(s, b, rt60=0.75, wet=0.32, slaps=((0.11, 0.22), (0.21, 0.08)), drive=2.3)


def shot_revolver(s):
    b = buf(1.4)
    gun_core(s, b, crack_tau=0.0016, hi=0.65, hi_tau=0.013, mid=1.0, mid_tau=0.045, low=1.0, low_tau=0.09,
             low_lp=360, th=1.1, th_f=(150, 42), th_tau=0.07)
    return master(s, b, rt60=1.05, wet=0.38, slaps=((0.13, 0.28), (0.26, 0.11)), drive=2.6)


def shot_smg(s):
    b = buf(0.5)
    gun_core(s, b, crack=0.9, crack_tau=0.001, hi=0.6, hi_tau=0.007, mid=0.85, mid_tau=0.018,
             mid_band=(500, 3000), low=0.6, low_tau=0.03, th=0.8, th_f=(210, 70), th_tau=0.025)
    place(b, s.burst(0.01, 0.0025, "bp", (1500, 5000), 0.22), s.j(0.016))
    return master(s, b, rt60=0.45, wet=0.2, slaps=((0.10, 0.12),), drive=2.0, peak=0.8)


def shot_auto(s):
    b = buf(0.7)
    gun_core(s, b, crack_tau=0.0012, hi=0.8, hi_tau=0.009, hi_band=(3000, 11500), mid=0.8, mid_tau=0.025,
             low=0.7, low_tau=0.045, th=0.9, th_f=(170, 55), th_tau=0.035)
    place(b, s.burst(0.01, 0.0022, "bp", (1800, 6000), 0.18), s.j(0.02))
    return master(s, b, rt60=0.6, wet=0.26, slaps=((0.11, 0.16),), drive=2.4, peak=0.85)


def shot_rifle(s):
    b = buf(1.8)
    gun_core(s, b, crack_tau=0.0018, hi=0.8, hi_tau=0.015, mid=1.0, mid_tau=0.05, low=1.0, low_tau=0.12,
             low_lp=300, th=1.1, th_f=(130, 38), th_tau=0.09)
    return master(s, b, rt60=1.4, wet=0.45, slaps=((0.14, 0.3), (0.29, 0.12)), drive=2.6, peak=0.92)


def shot_sniper(s):
    b = buf(2.4)
    # onda supersónica: dos chasquidos pegados (la onda N)
    place(b, s.burst(0.006, 0.0008, "hp", 2500, 0.9, attack=0.00003), 0.0)
    place(b, -s.burst(0.006, 0.0008, "hp", 2500, 0.7, attack=0.00003), 0.0018)
    gun_core(s, b, crack=0.7, crack_tau=0.002, hi=0.8, hi_tau=0.018, mid=1.0, mid_tau=0.06, low=1.1,
             low_tau=0.16, low_lp=260, th=1.2, th_f=(115, 32), th_tau=0.11)
    place(b, s.burst(0.9, 0.25, "lp", 150, 0.6, attack=0.01), 0.01)  # retumbo
    return master(s, b, rt60=1.9, wet=0.5, slaps=((0.16, 0.32), (0.34, 0.15), (0.55, 0.06)), drive=2.8, peak=0.95)


def _shotgun_blast(s, b, rough=1.0):
    gun_core(s, b, crack=0.9, crack_tau=0.0015, hi=0.6 * rough, hi_tau=0.012, mid=1.0 * rough, mid_tau=0.05,
             mid_band=(220, 2200), low=1.1, low_tau=0.11, low_lp=300, th=1.2, th_f=(110, 34), th_tau=0.1)


def shot_shotgun(s):
    b = buf(1.4)
    _shotgun_blast(s, b)
    # bomba: corredera atrás (raspado) y adelante (golpe seco)
    t0 = s.j(0.36, 0.5)
    place(b, s.burst(0.05, 0.012, "bp", (800, 4200), 0.32), t0)
    place(b, s.ring([1800, 2650, 3900], 0.01, 0.08), t0)
    t1 = t0 + s.j(0.12, 0.5)
    place(b, s.burst(0.04, 0.007, "bp", (1000, 5200), 0.42), t1)
    place(b, s.thump(0.08, 230, 150, 0.014, 0.28), t1)
    place(b, s.ring([2100, 3300], 0.008, 0.08), t1)
    return master(s, b, rt60=1.1, wet=0.4, slaps=((0.13, 0.28), (0.27, 0.1)), drive=2.8, peak=0.93)


def shot_sawed(s):
    b = buf(1.3)
    _shotgun_blast(s, b, rough=1.15)
    place(b, s.burst(0.25, 0.06, "bp", (180, 2600), 0.5), 0.004)  # el cañón corto escupe más
    return master(s, b, rt60=1.0, wet=0.38, slaps=((0.12, 0.3), (0.25, 0.1)), drive=3.2, peak=0.95)


def shot_enemy_gun(s):
    """Disparo de un enemigo armado: pistola un poco más lejana y apagada, para no confundirla con la propia."""
    b = buf(1.1)
    gun_core(s, b, crack=0.8, hi=0.5, mid=0.9, mid_tau=0.032, low=0.85, low_tau=0.06, th=0.75, th_f=(170, 55))
    return master(s, b, rt60=0.95, wet=0.48, slaps=((0.14, 0.3), (0.27, 0.12)), drive=2.0, peak=0.8,
                  dry_lp=4200)


def shot_nail(s):
    """Clavadora neumática: soplido de aire, golpe del percutor y un clank metálico."""
    b = buf(0.45)
    place(b, s.burst(0.012, 0.0025, "bp", (2000, 7500), 0.75, attack=0.0001), 0.0)
    place(b, s.ring([2400, 3700, 5200], 0.012, 0.16), 0.0)
    place(b, s.thump(0.12, 130, 70, 0.02, 0.6), 0.0)
    place(b, s.burst(0.12, 0.022, "bp", (1200, 6000), 0.55, attack=0.002), 0.002)
    place(b, s.burst(0.25, 0.06, "hp", 3200, 0.16, attack=0.01), 0.025)  # escape de aire
    place(b, s.burst(0.01, 0.002, "bp", (1500, 5000), 0.3), s.j(0.07))  # vuelta del percutor
    return master(s, b, rt60=0.35, wet=0.14, slaps=((0.09, 0.08),), drive=1.6, peak=0.75)


def shot_flare(s):
    """Pistola de bengalas: "tunk" hueco y el siseo de la bengala que se aleja chisporroteando."""
    b = buf(1.3)
    place(b, s.thump(0.25, 250, 85, 0.035, 1.0), 0.0)
    place(b, s.burst(0.2, 0.04, "lp", 1500, 0.8, attack=0.0008), 0.0)
    place(b, s.burst(0.008, 0.001, "hp", 2200, 0.35, attack=0.00005), 0.0)
    place(b, s.burst(1.0, 0.32, "hp", 2600, 0.24, attack=0.03), 0.02)
    place(b, s.crackle(1.0, 260, (1800, 7000), 0.55, start_tau=0.35), 0.03)
    return master(s, b, rt60=0.85, wet=0.3, slaps=((0.12, 0.15),), drive=1.8, peak=0.82)


def shot_extinguisher(s):
    """Matafuegos de CO2: chorro de gas helado. Dura más que el intervalo de disparo para fundirse en un chorro."""
    b = buf(0.34)
    n = len(b)
    place(b, s.filt(s.noise(n), "hp", 1400) * Synth.env(n, 0.12, attack=0.025, hold=0.12) * 0.7, 0.0)
    place(b, s.filt(s.noise(n), "bp", (3000, 9500)) * Synth.env(n, 0.09, attack=0.02, hold=0.1) * 0.45, 0.0)
    place(b, s.filt(s.noise(n), "lp", 320) * Synth.env(n, 0.1, attack=0.03, hold=0.08) * 0.5, 0.0)
    return master(s, b, rt60=0.3, wet=0.08, slaps=(), drive=1.3, peak=0.6)


def hit_flesh(s):
    b = buf(0.3)
    place(b, s.thump(0.12, 150, 60, 0.026, 1.0), 0.0)
    place(b, s.burst(0.1, 0.022, "lp", 1300, 0.7, attack=0.0008), 0.0)
    place(b, s.burst(0.14, 0.035, "bp", (550, 1900), 0.35, attack=0.004), 0.006)  # chapoteo
    return master(s, b, rt60=0.25, wet=0.08, slaps=(), drive=2.0, peak=0.75)


def hit_world(s):
    b = buf(0.6)
    place(b, s.burst(0.01, 0.0018, "hp", 2500, 0.85, attack=0.00005), 0.0)
    place(b, s.burst(0.12, 0.022, "bp", (700, 4200), 0.5, attack=0.0005), 0.0)
    place(b, s.crackle(0.2, 900, (2500, 8000), 0.35, start_tau=0.05), 0.005)  # astillas y polvo
    if s.rng.random() < 0.45:  # rebote: silbido que cae de tono
        n = int(0.32 * SR)
        t = np.arange(n) / SR
        f = s.j(3200) - 1300.0 * t / 0.32
        place(b, np.sin(2 * np.pi * np.cumsum(f) / SR) * Synth.env(n, 0.12, 0.01) * 0.16, 0.012)
    return master(s, b, rt60=0.4, wet=0.15, slaps=((0.1, 0.1),), drive=1.8, peak=0.7)


def boom_frag(s):
    b = buf(3.0)
    place(b, s.burst(0.03, 0.003, "hp", 1200, 1.0, attack=0.0001), 0.0)
    place(b, s.burst(0.9, 0.15, "bp", (150, 1600), 1.0, attack=0.002), 0.0)
    place(b, s.burst(1.8, 0.4, "lp", 200, 1.2, attack=0.006), 0.0)
    place(b, s.thump(1.2, 85, 26, 0.25, 1.2), 0.0)
    place(b, s.crackle(1.6, 140, (1800, 6500), 0.5, start_tau=0.5), 0.12)  # escombros que caen
    return master(s, b, rt60=1.8, wet=0.45, slaps=((0.18, 0.3), (0.38, 0.12)), drive=3.0, peak=0.95)


def shot_rocket(s):
    """Bazuca: golpe hueco del tubo y el rugido del motor del cohete que se aleja."""
    b = buf(1.4)
    place(b, s.thump(0.3, 140, 50, 0.06, 1.0), 0.0)
    place(b, s.burst(0.3, 0.05, "lp", 900, 0.9, attack=0.001), 0.0)
    place(b, s.burst(0.012, 0.0015, "hp", 1500, 0.5, attack=0.00005), 0.0)
    n = int(1.1 * SR)
    t = np.arange(n) / SR
    roar = s.filt(s.noise(n), "bp", (400, 4500)) * np.clip(t / 0.05, 0, 1) * np.exp(-t / 0.45)
    place(b, roar * 0.6, 0.02)
    place(b, s.crackle(1.0, 400, (1500, 6000), 0.25, start_tau=0.4), 0.04)
    return master(s, b, rt60=1.1, wet=0.35, slaps=((0.14, 0.2),), drive=2.2, peak=0.9)


def shot_dart(s):
    """Pistola de dardos: soplido de aire comprimido y el clic del gatillo."""
    b = buf(0.3)
    place(b, s.burst(0.008, 0.0015, "bp", (2500, 8000), 0.5, attack=0.0001), 0.0)
    place(b, s.burst(0.12, 0.03, "bp", (900, 5000), 0.8, attack=0.004), 0.0)
    place(b, s.thump(0.06, 180, 110, 0.012, 0.3), 0.0)
    return master(s, b, rt60=0.3, wet=0.1, slaps=(), drive=1.4, peak=0.6)


def shot_taser(s):
    """Taser: el tiro de los electrodos y el chisporroteo de la descarga."""
    b = buf(0.6)
    place(b, s.burst(0.01, 0.002, "hp", 2000, 0.7, attack=0.0001), 0.0)
    place(b, s.thump(0.08, 220, 120, 0.015, 0.4), 0.0)
    n = int(0.45 * SR)
    t = np.arange(n) / SR
    buzz = np.sign(np.sin(2 * np.pi * 60 * t)) * 0.3 + s.noise(n) * 0.7  # zumbido de red con arcos
    buzz = s.filt(buzz, "bp", (700, 6000)) * Synth.env(n, 0.18, attack=0.01, hold=0.15)
    place(b, buzz * 0.7, 0.03)
    place(b, s.crackle(0.45, 1400, (2000, 9000), 0.6, start_tau=0.3), 0.03)
    return master(s, b, rt60=0.3, wet=0.1, slaps=(), drive=2.0, peak=0.75)


def c4_beep(s):
    """C4: pitido electrónico limpio de armado."""
    b = buf(0.14)
    n = int(0.09 * SR)
    t = np.arange(n) / SR
    tone = (np.sin(2 * np.pi * 2350 * t) + 0.3 * np.sin(2 * np.pi * 4700 * t)) * Synth.env(n, 0.05, 0.002, hold=0.04)
    place(b, tone * 0.8, 0.0)
    return master(s, b, rt60=0.2, wet=0.05, slaps=(), drive=1.0, peak=0.5)


def shot_thunder(s):
    """Rayo de Zeus: chasquido eléctrico seco y el trueno que retumba."""
    b = buf(2.2)
    place(b, s.burst(0.006, 0.0008, "hp", 3000, 1.0, attack=0.00003), 0.0)
    place(b, s.crackle(0.25, 3000, (2500, 12000), 0.9, start_tau=0.06), 0.0)
    place(b, s.burst(0.5, 0.09, "bp", (300, 3000), 0.8, attack=0.002), 0.01)
    n = int(1.9 * SR)
    t = np.arange(n) / SR
    rumble = s.filt(s.noise(n), "lp", 160) * np.clip(t / 0.12, 0, 1) * np.exp(-t / 0.6)
    rumble *= 1.0 + 0.5 * np.sin(2 * np.pi * 3.5 * t + s.rng.uniform(0, 6))  # retumbo que va y viene
    place(b, rumble * 1.2, 0.04)
    return master(s, b, rt60=1.8, wet=0.4, slaps=((0.2, 0.25), (0.45, 0.12)), drive=2.6, peak=0.92)


def wave_splash(s):
    """Tridente de Poseidón: la ola que sale con el golpe."""
    b = buf(1.1)
    n = int(1.0 * SR)
    t = np.arange(n) / SR
    swell = s.filt(s.noise(n), "bp", (250, 3500)) * np.clip(t / 0.12, 0, 1) * np.exp(-np.maximum(0, t - 0.12) / 0.3)
    place(b, swell * 0.9, 0.0)
    place(b, s.thump(0.3, 110, 50, 0.07, 0.6), 0.0)
    place(b, s.crackle(0.8, 700, (1500, 7000), 0.35, start_tau=0.3), 0.08)  # espuma
    return master(s, b, rt60=0.7, wet=0.25, slaps=(), drive=1.6, peak=0.8)


def slash_light(s):
    """Excalibur: tajo de luz, un brillo agudo que zumba y se va."""
    b = buf(0.7)
    n = int(0.6 * SR)
    t = np.arange(n) / SR
    shimmer = np.zeros(n)
    for f in (1760, 2637, 3520, 5274):
        shimmer += np.sin(2 * np.pi * s.j(f, 0.3) * t * (1 + 0.15 * t)) / (f / 1760)
    shimmer *= Synth.env(n, 0.18, attack=0.01)
    place(b, shimmer * 0.35, 0.0)
    place(b, s.burst(0.2, 0.05, "bp", (2000, 9000), 0.5, attack=0.006), 0.0)
    return master(s, b, rt60=0.9, wet=0.35, slaps=(), drive=1.3, peak=0.7)


def axe_throw(s):
    """Hacha Leviatán: el silbido del hacha que sale girando."""
    b = buf(0.6)
    n = int(0.5 * SR)
    t = np.arange(n) / SR
    whirl = s.filt(s.noise(n), "bp", (500, 3000)) * (0.5 + 0.5 * np.sin(2 * np.pi * 14 * t)) * np.exp(-t / 0.2)
    place(b, whirl * 0.8, 0.0)
    place(b, s.burst(0.04, 0.008, "bp", (1500, 6000), 0.4), 0.0)
    return master(s, b, rt60=0.4, wet=0.12, slaps=(), drive=1.4, peak=0.7)


def axe_catch(s):
    """Hacha Leviatán: el hacha vuelve a la mano, golpe metálico con escarcha."""
    b = buf(0.6)
    place(b, s.thump(0.15, 180, 80, 0.03, 0.8), 0.0)
    place(b, s.ring([1240, 1870, 2930, 4410], 0.07, 0.35), 0.0)
    place(b, s.crackle(0.3, 1200, (4000, 12000), 0.3, start_tau=0.08), 0.0)  # hielo que cruje
    return master(s, b, rt60=0.5, wet=0.15, slaps=(), drive=1.6, peak=0.75)


def spear_throw(s):
    """Gungnir: la lanza sale cortando el aire con un zumbido grave."""
    b = buf(0.7)
    n = int(0.6 * SR)
    t = np.arange(n) / SR
    whoosh = s.filt(s.noise(n), "bp", (300, 2500)) * np.clip(t / 0.03, 0, 1) * np.exp(-t / 0.18)
    place(b, whoosh * 0.9, 0.0)
    hum = np.sin(2 * np.pi * 110 * t * (1 - 0.2 * t)) * np.exp(-t / 0.25) * 0.4
    place(b, hum, 0.0)
    return master(s, b, rt60=0.6, wet=0.2, slaps=(), drive=1.5, peak=0.72)


RECIPES = {
    "shot_pistol": shot_pistol,
    "shot_revolver": shot_revolver,
    "shot_smg": shot_smg,
    "shot_auto": shot_auto,
    "shot_rifle": shot_rifle,
    "shot_sniper": shot_sniper,
    "shot_shotgun": shot_shotgun,
    "shot_sawed": shot_sawed,
    "shot_enemy_gun": shot_enemy_gun,
    "shot_nail": shot_nail,
    "shot_flare": shot_flare,
    "shot_extinguisher": shot_extinguisher,
    "hit_flesh": hit_flesh,
    "hit_world": hit_world,
    "boom_frag": boom_frag,
    "shot_rocket": shot_rocket,
    "shot_dart": shot_dart,
    "shot_taser": shot_taser,
    "c4_beep": c4_beep,
    "shot_thunder": shot_thunder,
    "wave_splash": wave_splash,
    "slash_light": slash_light,
    "axe_throw": axe_throw,
    "axe_catch": axe_catch,
    "spear_throw": spear_throw,
}


def write_wav(path, x):
    data = (np.clip(x, -1.0, 1.0) * 32767.0).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def main():
    names = sys.argv[1:] or list(RECIPES)
    os.makedirs(OUT_DIR, exist_ok=True)
    for name in names:
        for v in range(1, VARIANTS + 1):
            seed = sum(map(ord, name)) * 31 + v  # fijo: correr el script dos veces da los mismos archivos
            x = RECIPES[name](Synth(seed))
            path = os.path.join(OUT_DIR, f"{name}_{v}.wav")
            write_wav(path, x)
        print(f"{name}: {VARIANTS} variantes, {len(x) / SR:.2f} s")


if __name__ == "__main__":
    main()
