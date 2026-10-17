// Surface the referral code carried by the invite link. No tracking, no
// redirect: the visitor chooses their store. `to` (the in-app destination)
// is intentionally ignored here — it becomes useful only once App Links
// association is live and this URL can open the app directly.
// External file on purpose: the site CSP (default-src 'self') blocks inline
// scripts, which silently disabled this logic when it lived in invite.html.
//
// Compétition ambassadeurs : le code s'affiche en grand avec un bouton
// « Copier le code ». Le lien Google Play porte aussi le code dans le paramètre
// `referrer` (Play Install Referrer) : l'app installée (2.3.0) l'ignore, la
// build 57 pourra le lire pour préremplir le code — sans rien changer ici.
(function () {
  var params = new URLSearchParams(window.location.search);
  // Un code est court et sans espace : on ne recopie rien d'autre dans la page.
  var ref = (params.get('ref') || '').trim().replace(/[^A-Za-z0-9-]/g, '').slice(0, 20);
  if (!ref) return;
  document.getElementById('ref-code').textContent = ref;
  document.getElementById('ref-card').hidden = false;

  var android = document.getElementById('android');
  android.href =
    'https://play.google.com/store/apps/details?id=com.karatou.android&referrer=' +
    encodeURIComponent('utm_source=invite&utm_medium=referral&ref=' + ref);

  var copied = document.getElementById('ref-copied');
  document.getElementById('ref-copy').addEventListener('click', function () {
    function done() {
      copied.hidden = false;
    }
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(ref).then(done, function () {
        fallbackCopy();
      });
    } else {
      fallbackCopy();
    }
    // Navigateurs sans presse-papiers asynchrone : sélection + execCommand.
    function fallbackCopy() {
      var field = document.createElement('textarea');
      field.value = ref;
      field.setAttribute('readonly', '');
      field.className = 'ref-copy-buffer';
      document.body.appendChild(field);
      field.select();
      try {
        if (document.execCommand('copy')) done();
      } catch (e) {
        // Rien : le code reste affiché, l'utilisateur peut le recopier.
      }
      document.body.removeChild(field);
    }
  });
})();
