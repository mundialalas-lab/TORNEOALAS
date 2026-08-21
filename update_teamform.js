const fs = require('fs');
let html = fs.readFileSync('ALAS-MUNDIAL.html', 'utf8');

const regex = /\$\("#teamForm"\)\.addEventListener\("submit",e=>\{[\s\S]*?playAdvance\(\);\s*\}\);/;
const replacement = `$("#teamForm").addEventListener("submit", async e=>{
        e.preventDefault();
        const name=$("#teamNameField").value.trim(),short=$("#teamShortField").value.trim();
        if(!name||!short)return;
        const id=editingTeamId||uid("t");
        const existing=state.teams[id];
        
        const submitBtn = e.target.querySelector('button[type="submit"]');
        const origText = submitBtn.textContent;
        submitBtn.textContent = "Guardando en nube...";
        submitBtn.disabled = true;

        let logoUrl = existing?.logoDataUrl||"";
        if (pendingTeamCrest !== null && pendingTeamCrest.startsWith('data:')) {
          const uploadedUrl = await uploadBase64ToSupabase(pendingTeamCrest, \`teams/\${id}_crest.png\`);
          if (uploadedUrl) logoUrl = uploadedUrl;
        }

        let photoUrl = existing?.photoDataUrl||"";
        if (pendingTeamPhoto !== null && pendingTeamPhoto.startsWith('data:')) {
          const uploadedUrl = await uploadBase64ToSupabase(pendingTeamPhoto, \`teams/\${id}_photo.png\`);
          if (uploadedUrl) photoUrl = uploadedUrl;
        }

        state.teams[id]={...(existing||{}),
          id,name,shortName:short,city:$("#teamCityField").value.trim(),category:$("#teamCategoryField").value.trim(),
          groupId:$("#teamGroupField").value,colorPrimary:$("#teamColor1Field").value,colorSecondary:$("#teamColor2Field").value,
          logoDataUrl:logoUrl,
          photoDataUrl:photoUrl,
          createdAt:existing?.createdAt||new Date().toISOString()};
          
        persist();

        if (window.supabase) {
           let groupUuid = null;
           const g = state.groups[$("#teamGroupField").value];
           if (g && g.uuid) groupUuid = g.uuid;

           const payload = {
             legacy_id: id,
             tournament_id: state.meta.tournamentUuid || 1,
             group_id: groupUuid || 1, // fallback
             name: name,
             short_name: short,
             city: $("#teamCityField").value.trim(),
             captain: $("#teamCategoryField").value.trim(),
             color_primary: $("#teamColor1Field").value,
             color_secondary: $("#teamColor2Field").value,
             crest_url: logoUrl,
             photo_url: photoUrl
           };
           const { data, error } = await window.supabase.from('teams').upsert(payload, { onConflict: 'legacy_id' }).select();
           if (!error && data && data.length > 0) {
              state.teams[id].uuid = data[0].id;
              persist(); 
           } else if (error) {
              console.error("Supabase upsert error:", error);
           }
        }

        submitBtn.textContent = origText;
        submitBtn.disabled = false;
        closeTeamModal();renderAll();showToast(existing?"Equipo actualizado":"Equipo creado");playAdvance();
      });`;

html = html.replace(regex, replacement);
fs.writeFileSync('ALAS-MUNDIAL.html', html);
console.log('teamForm submit handler updated.');
