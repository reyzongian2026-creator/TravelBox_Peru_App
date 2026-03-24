# TravelBox Peru - Configuración del Web Scraper
# ================================================

# URL Base - Producción
BASE_URL = "https://travelbox-frontend-prod-82181537443.us-central1.run.app"
BACKEND_URL = "https://travelbox-backend-prod-82181537443.us-central1.run.app"

# Credenciales de Login
CREDENTIALS = {
    "email": "admin@travelbox.pe",
    "password": "Admin123!"
}

# Timeouts (segundos)
TIMEOUT_PAGE_LOAD = 30
TIMEOUT_NETWORK_IDLE = 15

# Rutas a scrapear - Público
PUBLIC_ROUTES = [
    "/",
    "/discover",
    "/login",
    "/register",
    "/debug/text",
]

# Rutas a scrapear - Requiere autenticación
AUTH_ROUTES = [
    # Usuario Cliente
    "/discover",
    "/reservations",
    "/profile",
    "/notifications",
    "/warehouse/1",
    
    # Admin
    "/admin/dashboard",
    "/admin/users",
    "/admin/reservations",
    "/admin/payments-history",
    "/admin/warehouses",
    "/admin/incidents",
    "/admin/ratings",
    
    # Courier
    "/courier/panel",
    "/courier/services",
    
    # Operator
    "/operator/dashboard",
    "/ops-qr",
    
    # Warehouse Admin
    "/warehouses",
]

# Selector CSS para extraer texto
TEXT_SELECTORS = [
    "body",
    "h1", "h2", "h3", "h4", "h5", "h6",
    "p", "span", "div",
    "label",
    "a",
    "button",
    "input[placeholder]",
    "title",
]

# Elementos a excluir
EXCLUDE_SELECTORS = [
    "script",
    "style",
    "noscript",
    "<!--", 
    "-->",
    "[hidden]",
    ".hidden",
    "#hidden",
]

# Output
OUTPUT_DIR = "output"
OUTPUT_FILE_TXT = f"{OUTPUT_DIR}/texto_extraido.txt"
OUTPUT_FILE_JSON = f"{OUTPUT_DIR}/texto_extraido.json"
OUTPUT_FILE_CSV = f"{OUTPUT_DIR}/texto_extraido.csv"

# Logging
LOG_LEVEL = "INFO"  # DEBUG, INFO, WARNING, ERROR
LOG_FILE = f"{OUTPUT_DIR}/scraper.log"