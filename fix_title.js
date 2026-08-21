const fs = require('fs');
let html = fs.readFileSync('ALAS-MUNDIAL.html', 'utf8');

const regex = /\$\("#matchDataModalTitle"\)\.innerHTML=`\$\{esc\(teamName\(resolveSlot\(m\.homeSlot\)\)\)\} vs \$\{esc\(teamName\(resolveSlot\(m\.awaySlot\)\)\)\}`;/;
const replacement = `$("#matchDataModalTitle").innerHTML=\`\${teamName(resolveSlot(m.homeSlot))} vs \${teamName(resolveSlot(m.awaySlot))}\`;`;

html = html.replace(regex, replacement);

fs.writeFileSync('ALAS-MUNDIAL.html', html);
console.log('Fixed modal title');
