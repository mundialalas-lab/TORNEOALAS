const fs = require('fs');
let html = fs.readFileSync('ALAS-MUNDIAL.html', 'utf8');

const replacement = `function openConfig() {
        const countSpan = $("#onlineUsersCount");
        if(countSpan) {
          const now = Date.now();
          const allUsers = usersList();
          const onlineUsers = allUsers.filter(u => u.lastSeen && (now - new Date(u.lastSeen).getTime()) < 5*60*1000);
          const names = onlineUsers.map(u => u.name).join(", ");
          countSpan.innerHTML = \`Registrados: <b>\${allUsers.length}</b>. Online (últimos 5m): <b>\${onlineUsers.length}</b>\${names ? \`<br><small style="color:var(--text-muted)">\${esc(names)}</small>\` : ''}\`;
        }
        $("#tournamentName").value=state.tournament.name;
        $("#tournamentSubtitle").value=state.tournament.subtitle;
        $("#numGroupsField").value=state.format.numGroups;
        $("#qualifiersField").value=state.format.qualifiersPerGroup;
        $("#yellowField").value=state.format.yellowCardsSuspension;
        $("#redSuspField").value=state.format.redCardSuspensionMatches;
        $("#doubleRRField").checked=state.format.doubleRoundRobin;
        $("#thirdPlaceField").checked=state.format.thirdPlaceMatch;
        $("#h2hField").checked=state.format.tiebreakerHeadToHead;
        $("#soundEnabledField").checked=state.settings.sound;
        $("#confettiEnabledField").checked=state.settings.confetti;
        $("#volumeField").value=Math.round((state.settings.volume||0.7)*100);
        $("#volumeValue").textContent=$("#volumeField").value+"%";
        document.querySelector('[data-tab="config"]')?.click();
      }`;

html = html.replace(/function openConfig\(\) \{ document\.querySelector\('\\[data-tab="config"\\]'\)\?\.click\(\); \}/, replacement);

fs.writeFileSync('ALAS-MUNDIAL.html', html);
console.log('HTML updated');
