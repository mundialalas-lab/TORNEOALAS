const fs = require('fs');
let html = fs.readFileSync('ALAS-MUNDIAL.html', 'utf8');

html = html.replace(/logoDataUrl:\s*t\.photo_path\s*\|\|\s*countryToFlag\[t\.country_name\]\s*\|\|\s*""\s*,/g, 'logoDataUrl: t.crest_url || countryToFlag[t.country_name] || "",');
html = html.replace(/photoDataUrl:\s*t\.photo_path\s*\|\|\s*countryToFlag\[t\.country_name\]\s*\|\|\s*""\s*,/g, 'photoDataUrl: t.photo_url || countryToFlag[t.country_name] || "",');

html = html.replace(/photoDataUrl:\s*p\.photo_path\s*\|\|\s*""/g, 'photoDataUrl: p.photo_url || ""');

fs.writeFileSync('ALAS-MUNDIAL.html', html);
console.log('Fixed syncFromSupabase paths');
