const fs = require('fs');
let html = fs.readFileSync('ALAS-MUNDIAL.html', 'utf8');

// 1. Move configModal to app-tab
const configModalRegex = /<div class="modal-backdrop" id="configModal".*?<\/form>\s*<\/div>\s*<\/div>/s;
const match = html.match(configModalRegex);
if (!match) throw new Error('configModal not found');

const bodyRegex = /<div class="modal-body">(.*?)<\/div>\s*<footer class="modal-actions">/s;
const bodyMatch = match[0].match(bodyRegex);

let newTab = `    <div class="app-tab" id="tab-config">
      <section class="panel">
        <div class="panel-head">
          <div><h2>Configuración del torneo</h2><p>Personalizá la competencia, equipos, colores y experiencia sonora.</p></div>
          <span class="admin-tag">Sólo administrador</span>
        </div>
        <form id="configForm">
          <div class="config-body" style="padding: 16px;">
${bodyMatch[1]}
          </div>
          <div style="padding: 16px; border-top: 1px solid rgba(255,255,255,0.1);">
            <button class="btn primary" type="submit" style="width:100%; min-height:48px; border-radius:12px;">Guardar configuración</button>
          </div>
        </form>
      </section>
    </div>
`;

// Replace the modal with empty string
html = html.replace(configModalRegex, '');

// Inject the new tab just before </main>
html = html.replace('</main>', newTab + '\n  </main>');

// 2. Change btnConfigureMob to use data-tab
html = html.replace(
  'id="btnConfigureMob" type="button"',
  'data-tab="config" type="button"'
);

// 3. Change reset button text
html = html.replace(
  /onclick="resetearPuntosTorneo\(\)">Resetear Torneo<\/button>/g,
  'onclick="resetearPuntosTorneo()">RESETEAR PUNTOS Y RESULTADOS</button>'
);

// 4. Fix openConfig / closeConfig JS
html = html.replace(
  /function openConfig\(\)\{[\s\S]*?playClick\(\);\s*\}/,
  `function openConfig() { document.querySelector('[data-tab="config"]')?.click(); }`
);
html = html.replace(
  /function closeConfig\(\)\{[^}]*\}/,
  `function closeConfig() { document.querySelector('[data-tab="mapa"]')?.click(); }`
);

// Remove event listeners for modal
html = html.replace('$("#btnCloseModal").addEventListener("click",closeConfig);', '// modal removed');
html = html.replace('$("#btnCancelModal").addEventListener("click",closeConfig);', '// modal removed');
html = html.replace('$("#configModal").addEventListener("click",e=>{if(e.target===e.currentTarget)closeConfig()});', '// modal removed');

fs.writeFileSync('ALAS-MUNDIAL.html', html);
console.log('HTML updated successfully');
