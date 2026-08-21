const fs = require('fs');
let html = fs.readFileSync('ALAS-MUNDIAL.html', 'utf8');

const oldMtFoot = `        return \`<div class="mt-foot" style="display:flex; flex-direction:column; width:100%;">
          <div style="text-align:center; width:100%; margin-bottom:4px;">
            <span>\${label}\${extra?"  "+extra:""}</span>
          </div>
          <div style="display:flex; gap:8px; width:100%; margin-top:4px;">
            \${dataBtn}
            \${editBtn}
            \${registrarBtn || verResultadosBtn}
          </div>
        </div>\`;`;

const newMtFoot = `        const statusStr = STATUS_LABEL[m.status] || m.status;
        const statusClass = m.status === "finished" ? "defined" : (m.status === "live" ? "live" : "");
        const statusBadge = \`<span class="match-status \${statusClass}" style="margin-bottom:12px; display:inline-block;">\${statusStr}</span>\`;

        return \`<div class="mt-foot" style="display:flex; flex-direction:column; width:100%; align-items:center;">
          \${statusBadge}
          <div style="text-align:center; width:100%; margin-bottom:8px;">
            <span>\${label}\${extra?"  "+extra:""}</span>
          </div>
          <div style="display:flex; flex-direction:column; gap:8px; width:100%;">
            \${dataBtn}
            \${editBtn}
            \${registrarBtn || verResultadosBtn}
          </div>
        </div>\`;`;

html = html.replace(oldMtFoot, newMtFoot);

const cssToAdd = `
/* BLOOM DORADO VER DETALLES */
.group-matches > summary {
  color: #ffd700 !important;
  background: rgba(255, 215, 0, 0.08) !important;
  box-shadow: 0 0 15px rgba(255, 215, 0, 0.15) !important;
  border: 1px solid rgba(255, 215, 0, 0.25) !important;
  border-radius: 12px !important;
  margin: 12px !important;
  transition: all 0.3s ease !important;
}
.group-matches > summary:hover {
  background: rgba(255, 215, 0, 0.15) !important;
  box-shadow: 0 0 20px rgba(255, 215, 0, 0.3) !important;
}
`;

html = html.replace('/* ANIMACION PARA DESPLEGAR PARTIDOS */', cssToAdd + '\n/* ANIMACION PARA DESPLEGAR PARTIDOS */');

fs.writeFileSync('ALAS-MUNDIAL.html', html);
console.log('Updated mtFoot and CSS.');
