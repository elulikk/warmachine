"""Genera la hoja de cálculo con los prompts de proyectiles básicos para Google Flow."""
from openpyxl import Workbook
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.utils import get_column_letter

ESTILO = (
    "estilo pixel art de videojuego 2D, bordes nítidos, vista lateral, "
    "aislado sobre fondo negro liso, brillo sutil cian, sin texto, sin sombra de suelo, "
    "sprite pequeño"
)

# id, nombre, descripción específica
PROYECTILES = [
    ("bala_pistola", "Bala de pistola", "una bala de pistola de metal dorado"),
    ("bala_smg", "Bala de SMG", "una bala pequeña de subfusil de latón, más corta y delgada"),
    ("bala_rifle", "Bala de rifle", "una bala larga de rifle de punta afilada, metal dorado y cobre"),
    ("perdigon", "Perdigón de escopeta", "un perdigón de plomo gris metálico, redondo y pequeño"),
    ("bala_francotirador", "Bala de francotirador", "una bala muy larga y fina de francotirador, metal plateado"),
    ("flecha", "Flecha", "una flecha de madera con punta metálica y plumas blancas"),
    ("dardo", "Dardo", "un dardo corto metálico con aleta de plástico violeta"),
    ("granada", "Granada", "una granada de mano verde oliva con palanca de seguridad"),
    ("cohete", "Cohete", "un cohete pequeño de metal rojo con llama naranja en la cola"),
    ("bola_plasma", "Bola de plasma", "una esfera de energía cian brillante con núcleo blanco"),
    ("laser", "Rayo láser", "un destello alargado de láser rojo con núcleo blanco"),
    ("bumeran", "Bumerán", "un bumerán de madera curvo con bordes de metal"),
]

ENCABEZADOS = ["ID", "Nombre", "Prompt para Google Flow", "Archivo esperado", "Estado"]

wb = Workbook()
ws = wb.active
ws.title = "Proyectiles"
ws.append(ENCABEZADOS)

for pid, nombre, descripcion in PROYECTILES:
    prompt = f"Genera una imagen de {descripcion}, {ESTILO}."
    ws.append([pid, nombre, prompt, f"{pid}.png", "Pendiente"])

encabezado_fill = PatternFill("solid", fgColor="1F2937")
for celda in ws[1]:
    celda.font = Font(bold=True, color="FFFFFF")
    celda.fill = encabezado_fill
    celda.alignment = Alignment(vertical="center")

anchos = {"A": 20, "B": 24, "C": 90, "D": 22, "E": 14}
for letra, ancho in anchos.items():
    ws.column_dimensions[letra].width = ancho
for fila in ws.iter_rows(min_row=2):
    for celda in fila:
        celda.alignment = Alignment(wrap_text=True, vertical="top")
ws.freeze_panes = "A2"

wb.save(r"C:\Users\Usuario\Documents\warmachine\assets\sprites\proyectiles\proyectiles_basicos.xlsx")
print("OK", len(PROYECTILES), "proyectiles")
