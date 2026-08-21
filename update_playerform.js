const fs = require('fs');
let html = fs.readFileSync('ALAS-MUNDIAL.html', 'utf8');

const regex = /\$\("#playerForm"\)\.addEventListener\("submit\",e=>\{[\s\S]*?playAdvance\(\);\s*\}\);/;
const replacement = `$("#playerForm").addEventListener("submit", async e=>{
        e.preventDefault();
        if(!currentTeamSheetId)return;
        if(!puedeEditarEquipo(currentTeamSheetId)){showToast("No tenés permiso para tocar este plantel");return}
        const first=$("#playerFirstField").value.trim(),last=$("#playerLastField").value.trim();
        const num=Number($("#playerNumberField").value);
        if(!first||!last||!Number.isFinite(num))return;
        const id=editingPlayerId||uid("p");
        const existing=state.players[id];

        const submitBtn = e.target.querySelector('button[type="submit"]');
        const origText = submitBtn.textContent;
        submitBtn.textContent = "Guardando en nube...";
        submitBtn.disabled = true;

        let photoUrl = existing?.photoDataUrl||"";
        if (pendingPlayerPhoto !== null && pendingPlayerPhoto.startsWith('data:')) {
          const uploadedUrl = await uploadBase64ToSupabase(pendingPlayerPhoto, \`players/\${id}_photo.png\`);
          if (uploadedUrl) photoUrl = uploadedUrl;
        }

        state.players[id]={id,teamId:currentTeamSheetId,firstName:first,lastName:last,number:num,
          position:$("#playerPositionField").value,birthDate:$("#playerBirthField").value,
          photoDataUrl:photoUrl};
        persist();

        if (window.supabase) {
           const teamUuid = state.teams[currentTeamSheetId]?.uuid || 1; // fallback
           const payload = {
             legacy_id: id,
             team_id: teamUuid,
             first_name: first,
             last_name: last,
             number: num,
             position: $("#playerPositionField").value,
             birth_date: $("#playerBirthField").value || null,
             photo_url: photoUrl
           };
           const { data, error } = await window.supabase.from('players').upsert(payload, { onConflict: 'legacy_id' }).select();
           if (!error && data && data.length > 0) {
              state.players[id].uuid = data[0].id;
              persist();
           } else if (error) {
              console.error("Supabase upsert error:", error);
           }
        }

        submitBtn.textContent = origText;
        submitBtn.disabled = false;

        closePlayerModal();renderAll();
        resaltarJugador(id);
        showToast(existing?"Jugador actualizado":"Jugador agregado");playAdvance();
      });`;

html = html.replace(regex, replacement);
fs.writeFileSync('ALAS-MUNDIAL.html', html);
console.log('playerForm submit handler updated.');
