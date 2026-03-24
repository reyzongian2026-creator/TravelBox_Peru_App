#!/usr/bin/env python3
"""
TravelBox Peru - Web Scraper para extraer texto
=================================================

Este script automatiza la extraccion de texto de la aplicacion web TravelBox Peru.

Uso:
    pip install -r requirements.txt
    python scraper.py

Autor: TravelBox Peru Team
Fecha: 2026-03-22
"""

import asyncio
import json
import os
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Set

# Importaciones de Playwright
from playwright.async_api import async_playwright, Browser, Page, Playwright

# Importaciones locales
import config


class TravelBoxScraper:
    """Scraper principal para TravelBox Peru"""
    
    def __init__(self):
        self.browser: Browser = None
        self.page: Page = None
        self.playwright: Playwright = None
        self.collected_text: Dict[str, List[str]] = {}
        self.all_unique_text: Set[str] = set()
        self.session_cookies: List[Dict] = []
        
    async def initialize(self):
        """Inicializa el navegador"""
        print("[*] Inicializando navegador...")
        self.playwright = await async_playwright().start()
        self.browser = await self.playwright.chromium.launch(
            headless=True,
            args=[
                '--disable-blink-features=AutomationControlled',
                '--no-sandbox',
                '--disable-dev-shm-usage',
                '--disable-gpu',
                '--disable-software-rasterizer',
                '--window-size=1920,1080',
                '--allow-file-access-from-files',
            ]
        )
        self.page = await self.browser.new_page(
            viewport={'width': 1920, 'height': 1080},
            user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        )
        
        # Set up response handler to detect when Flutter finishes loading
        self.page.on("framenavigated", self._on_frame_navigated)
        
        # Configure timeouts
        self.page.set_default_timeout(config.TIMEOUT_PAGE_LOAD * 1000)
        
        print("[*] Navegador inicializado")
    
    def _on_frame_navigated(self, frame):
        """Handle frame navigation events"""
        pass
        
    async def login(self) -> bool:
        """Iniciar sesion en la aplicacion"""
        print(f"[*] Intentando login en {config.BASE_URL}/login...")
        
        try:
            # Navegar a pagina de login
            await self.page.goto(f"{config.BASE_URL}/login", wait_until="networkidle")
            await asyncio.sleep(3)
            
            # Check current URL
            current_url = self.page.url
            print(f"    [i] URL actual: {current_url}")
            
            # Get all input fields
            all_inputs = await self.page.query_selector_all('input')
            print(f"    [i] Encontrados {len(all_inputs)} elementos input")
            
            # Try to find email and password inputs with more flexible selectors
            email_input = await self.page.query_selector('input[type="email"], input[type="text"], input[name*="email"], input[name*="user"], input[id*="email"], input[id*="user"]')
            password_input = await self.page.query_selector('input[type="password"], input[name*="password"], input[name*="pass"], input[id*="password"], input[id*="pass"]')
            
            if email_input and password_input:
                print(f"    [i] Campos de login encontrados")
                # Ingresar credenciales
                await email_input.fill(config.CREDENTIALS["email"])
                await asyncio.sleep(0.5)
                await password_input.fill(config.CREDENTIALS["password"])
                await asyncio.sleep(0.5)
                
                # Buscar boton de submit - try multiple selectors
                submit_button = await self.page.query_selector('button[type="submit"], button:not([type]), button:has-text("Iniciar"), button:has-text("Login"), button:has-text("Entrar"), [role="button"]')
                
                if submit_button:
                    await submit_button.click()
                    await self.page.wait_for_load_state("networkidle")
                    await asyncio.sleep(5)
                    
                    # Check if login was successful by looking at URL change or element
                    print(f"    [i] URL despues de login: {self.page.url}")
                    
                    print("[*] Login exitoso")
                    return True
                else:
                    print("[!] No se encontró botón de submit")
            else:
                print("[!] No se encontraron campos de login")
                # Print HTML for debugging
                html = await self.page.content()
                print(f"    [i] HTML length: {len(html)}")
                
            return False
            
        except Exception as e:
            print(f"[!] Error en login: {e}")
            import traceback
            traceback.print_exc()
            return False
            
    async def extract_text_from_page(self, route: str) -> List[str]:
        """Extrae todo el texto visible de una pagina"""
        text_content = []
        
        try:
            full_url = f"{config.BASE_URL}{route}" if route != "/" else config.BASE_URL
            
            print(f"    [*] Extrayendo texto de: {route}")
            
# Navigate to the route - basic loading
            await self.page.goto(full_url, wait_until="domcontentloaded", timeout=config.TIMEOUT_PAGE_LOAD * 1000)
            
            # Wait a bit for initial load
            await asyncio.sleep(2)
            
            # Wait for networkidle to ensure resources are loaded
            try:
                await self.page.wait_for_load_state("networkidle", timeout=30000)
            except:
                pass
            
            # Additional wait for Flutter rendering
            await asyncio.sleep(5)
            
            # Debug: Get text content length before extracting
            initial_text = await self.page.evaluate("() => document.body.innerText.trim().length")
            print(f"    [i] Body text length: {initial_text}")
            
            # Get page HTML for debugging
            html_snippet = await self.page.content()
            if len(html_snippet) < 500:
                print(f"    [!] HTML muy pequeno: {len(html_snippet)} chars")
            else:
                print(f"    [i] HTML size: {len(html_snippet)} chars")
            
            # Scroll to trigger lazy-loaded content (multiple passes)
            for _ in range(3):
                await self.page.evaluate("""
                    () => {
                        window.scrollTo(0, document.body.scrollHeight);
                    }
                """)
                await asyncio.sleep(1)
            
            # Final scroll to top
            await self.page.evaluate("() => window.scrollTo(0, 0)")
            await asyncio.sleep(1)
            
            # Final scroll to top
            await self.page.evaluate("() => window.scrollTo(0, 0)")
            await asyncio.sleep(1)
            
            # Extraer texto usando JavaScript - try multiple approaches
            page_text = await self.page.evaluate("""
                () => {
                    const texts = [];
                    
                    // Approach 1: Get all text from body using innerText (may work after Flutter renders)
                    try {
                        const bodyText = document.body.innerText;
                        if (bodyText && bodyText.trim().length > 0) {
                            const lines = bodyText.split(/\\n/).filter(l => l.trim().length > 0);
                            lines.forEach(line => {
                                const trimmed = line.trim();
                                if (trimmed.length > 0 && trimmed.length < 500) {
                                    texts.push(trimmed);
                                }
                            });
                        }
                    } catch(e) {}
                    
                    // Approach 2: Check for Flutter injected scripts with localization data
                    const scripts = document.querySelectorAll('script');
                    scripts.forEach(script => {
                        try {
                            const content = script.textContent || script.innerHTML || '';
                            // Look for translation/localization patterns
                            if (content.includes('Intl') || content.includes('ARB') || content.includes('locale')) {
                                const matches = content.match(/"([^"]+)":\s*"([^"]+)"/g);
                                if (matches) {
                                    matches.forEach(m => {
                                        const parts = m.match(/"([^"]+)":\s*"([^"]+)"/);
                                        if (parts && parts[2].length > 0 && parts[2].length < 200) {
                                            texts.push(parts[2]);
                                        }
                                    });
                                }
                            }
                        } catch(e) {}
                    });
                    
                    // Approach 3: Get textContent of body as last resort
                    if (texts.length === 0) {
                        const bodyContent = document.body.textContent;
                        if (bodyContent && bodyContent.trim().length > 0) {
                            const lines = bodyContent.split(/\\n/).filter(l => l.trim().length > 0);
                            lines.forEach(line => {
                                const trimmed = line.trim();
                                if (trimmed.length > 0 && trimmed.length < 500) {
                                    texts.push(trimmed);
                                }
                            });
                        }
                    }
                    
                    // Remove duplicates
                    return [...new Set(texts)];
                }
            """)
            
            if page_text:
                text_content.extend(page_text)
                print(f"    [OK] {len(page_text)} textos extraidos")
            else:
                print(f"    [!] No se extrajo texto")
                
        except Exception as e:
            print(f"    [!] Error extrayendo {route}: {e}")
            
        return text_content
        
    async def scrape_all_routes(self):
        """Scrapear todas las rutas configuradas"""
        print(f"[*] Iniciando scrapeo de {len(config.PUBLIC_ROUTES + config.AUTH_ROUTES)} rutas...")
        
        # Primero rutas publicas
        print("\n=== RUTAS PUBLICAS ===")
        for route in config.PUBLIC_ROUTES:
            texts = await self.extract_text_from_page(route)
            self.collected_text[route] = texts
            self.all_unique_text.update(texts)
            
        # Intentar login para rutas autenticadas
        login_success = await self.login()
        
        if login_success:
            print("\n=== RUTAS AUTENTICADAS ===")
            for route in config.AUTH_ROUTES:
                texts = await self.extract_text_from_page(route)
                self.collected_text[route] = texts
                self.all_unique_text.update(texts)
        else:
            print("\n[!] No se pudo autenticar, omitiendo rutas autenticadas")
            
    async def save_results(self):
        """Guardar los resultados en archivos"""
        print(f"\n[*] Guardando resultados...")
        
        # Crear directorio de output
        output_dir = Path(config.OUTPUT_DIR)
        output_dir.mkdir(exist_ok=True)
        
        # 1. Guardar JSON completo
        with open(config.OUTPUT_FILE_JSON, 'w', encoding='utf-8') as f:
            json.dump({
                "metadata": {
                    "scraped_at": datetime.now().isoformat(),
                    "base_url": config.BASE_URL,
                    "total_routes": len(self.collected_text),
                    "total_unique_texts": len(self.all_unique_text)
                },
                "text_by_route": self.collected_text,
                "all_unique_text": sorted(list(self.all_unique_text))
            }, f, ensure_ascii=False, indent=2)
            
        print(f"[OK] JSON guardado: {config.OUTPUT_FILE_JSON}")
        
        # 2. Guardar TXT simple
        with open(config.OUTPUT_FILE_TXT, 'w', encoding='utf-8') as f:
            f.write(f"TravelBox Peru - Texto Extraido\n")
            f.write(f"Fecha: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"Total textos unicos: {len(self.all_unique_text)}\n")
            f.write(f"{'='*50}\n\n")
            
            for text in sorted(self.all_unique_text):
                f.write(f"- {text}\n")
                
        print(f"[OK] TXT guardado: {config.OUTPUT_FILE_TXT}")
        
        # Calculate frequencies from collected text
        text_freq = {}
        for route, texts in self.collected_text.items():
            for text in texts:
                text_freq[text] = text_freq.get(text, 0) + 1
        
        # 3. Guardar CSV
        with open(config.OUTPUT_FILE_CSV, 'w', encoding='utf-8') as f:
            f.write("texto,ruta,frecuencia\n")
            for route, texts in self.collected_text.items():
                for text in texts:
                    freq = text_freq.get(text, 1)
                    # Escapar comillas en CSV
                    escaped_text = text.replace('"', '""')
                    f.write(f'"{escaped_text}","{route}",{freq}\n')
                    
        print(f"[OK] CSV guardado: {config.OUTPUT_FILE_CSV}")
        
    async def close(self):
        """Cerrar navegador"""
        if self.browser:
            await self.browser.close()
        if self.playwright:
            await self.playwright.stop()
        print("[*] Navegador cerrado")
        
    async def run(self):
        """Ejecutar el scraper"""
        print("="*60)
        print("  TravelBox Peru - Web Scraper")
        print("="*60)
        print(f"URL Base: {config.BASE_URL}")
        print(f"Rutas a scrapear: {len(config.PUBLIC_ROUTES + config.AUTH_ROUTES)}")
        print("="*60)
        
        try:
            await self.initialize()
            await self.scrape_all_routes()
            await self.save_results()
            
            print("\n" + "="*60)
            print("  RESUMEN")
            print("="*60)
            print(f"Rutas scrapedas: {len(self.collected_text)}")
            print(f"Textos unicos encontrados: {len(self.all_unique_text)}")
            print(f"Archivos generados:")
            print(f"  - {config.OUTPUT_FILE_JSON}")
            print(f"  - {config.OUTPUT_FILE_TXT}")
            print(f"  - {config.OUTPUT_FILE_CSV}")
            print("="*60)
            
        except Exception as e:
            print(f"[!] Error ejecutando scraper: {e}")
            raise
            
        finally:
            await self.close()


async def main():
    """Punto de entrada principal"""
    scraper = TravelBoxScraper()
    await scraper.run()


if __name__ == "__main__":
    print("Ejecutando TravelBox Web Scraper...")
    print("Primero instala las dependencias:")
    print("  pip install -r requirements.txt")
    print("  playwright install chromium")
    print("")
    
    # Verificar que existen las dependencias
    try:
        import playwright
    except ImportError:
        print("[!] Playwright no esta instalado.")
        print("    Ejecuta: pip install playwright && playwright install chromium")
        sys.exit(1)
        
    # Ejecutar scraper
    asyncio.run(main())
    
    print("\n[OK] Scraper completado exitosamente!")