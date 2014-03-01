var connectedUserCount = 0;

function onBodyLoad()
{
    redirectToUniqueURL();
    hideProgressBar();
    hideFileUploadInput();
    performBrowserCheck();

    document.getElementById("connectedMessage").innerHTML = "Connected Users: ";

    connectUsers();
}

function setupDropArea()
{
    // fileDropArea border change on hover (like gmail attachments)
    var drop = document.getElementById("dropzone");

    drop.addEventListener("dragover", change, false);
    drop.addEventListener("dragenter", change, false);
    drop.addEventListener("dragleave", change_back, false);
    drop.addEventListener("dragend", change_back, false);
    drop.addEventListener("drop", change_back, false);

    function change() { drop.style.border = "2px dashed"; }
    function change_back() { drop.style.border = ""; }   
}

function redirectToUniqueURL()
{
    // Check to see if we have a unique URL, if not, redirect to one.

    var urlParams = getURLparams();
    if ( !urlParams.id )
        window.location.replace( document.URL + '?id=' + createGuid() );
}

function getURLparams()
{
    var params = {};

    if ( location.search ) {
        var parts = location.search.substring(1).split('&');

        for (var i = 0; i < parts.length; i++) {
            var nv = parts[i].split('=');
            if (!nv[0]) continue;
            params[nv[0]] = nv[1] || true;
        }
    }

    return params;
}        

function hideFileUploadInput()
{
    $('#fileupload').hide();
}

function hideProgressBar()
{
    $('#progressDiv').hide();
}

function showProgressBar()
{
    $('#progressDiv').show();
}

function performBrowserCheck()
{
    // check to see if the browser is chrome or not (we only support chrome).
    // if we aren't chrome then set the innerText of the warning div as just a space (we don't warn).

    var is_chrome = navigator.userAgent.toLowerCase().indexOf('chrome') > -1;

    if (!is_chrome)
    {
        document.getElementById("chromeWarning").innerText = "This site is designed and tested for use on Chrome only!";
    }
    else
    {
        $('#chromeWarning').hide();
    }
}

function connectUsers()
{
    // TODO: actually check user count and modify innerHTML to feature that many anonymousAnimal images. Max should probably be 2.
    if ( connectedUserCount == 2 )
        return;

    connectedUserCount++;
    updateUserGlyphs();
}

function updateUserGlyphs()
{
    document.getElementById("connectedMessage").innerHTML += "<img src='static/resources/monkey.png'> <img src='static/resources/hyena.png'>";
}

function sendFile( filename, data )
{
    // TODO: add support for updating the progress bar as the file transfer occurs (true file transfer percentage/progress)

    hideInstructions();
    showProgressBar();
    window.setTimeout(function(){

        var progress = "100%";

        document.getElementById("filename").innerText = "Sending: " + filename;
        document.getElementById("progressbar").style.width = progress;

    }, 200);
}

function hideInstructions()
{
    $('#instructions').hide();
}

function createGuid()
{
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c)
    {
        var r = Math.random()*16|0, v = c === 'x' ? r : (r&0x3|0x8);
        return v.toString(16);
    });
}