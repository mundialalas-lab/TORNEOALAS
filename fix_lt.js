const fs = require('fs');
let html = fs.readFileSync('ALAS-MUNDIAL.html', 'utf8');

const target = '<button class="lt-edit admin-only" type="button" data-open-match="${m.id}" aria-label="Cargar resultado">${ICO.edit}</button>';
const replacement = `<div class="lt-actions admin-only" style="position:absolute; top:4px; right:4px; display:flex; flex-direction:column; gap:4px; z-index:10;">
            <button class="lt-edit" type="button" data-open-match="\${m.id}" aria-label="Cargar resultado" style="position:relative; top:auto; right:auto;">\${ICO.edit}</button>
            <button class="lt-edit btn-edit-datos" type="button" data-open-match-data="\${m.id}" aria-label="Datos" style="position:relative; top:auto; right:auto; font-size:9px; font-weight:bold; width:22px; height:22px;">DAT</button>
          </div>`;

html = html.replace(target, replacement);
fs.writeFileSync('ALAS-MUNDIAL.html', html);
console.log('Done');
