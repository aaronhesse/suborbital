var connectedUserCount = 0;

var userIDMap =
{
    1: "monkey",
    2: "hyena",
}

function onBodyLoad()
{
    setupDropArea();
    redirectToUniqueURL();
    hideProgressBar();
    hideFileUploadInput();
    performBrowserCheck();
    connectUser();
}

function setupDropArea()
{
    document.addEventListener("DOMContentLoaded", function(e)
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
        
    }, true); 
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
    if (!browserIsChrome())
        setChromeWarningText();
}

function browserIsChrome()
{
    return navigator.userAgent.toLowerCase().indexOf('chrome') > -1;
}

function setChromeWarningText()
{
    document.getElementById("chromeWarning").innerText = "This site is designed and tested for use on Chrome only!";
}

function connectUser()
{
    // We may have to talk with heroku or the websockets server to keep track of the connectedUsers.
    if ( connectedUserCount == 2 )
        return;

    connectedUserCount++;
    updateUserGlyphs();
}

function updateUserGlyphs()
{
    document.getElementById("connectedMessage").innerHTML = "Connected Users: ";

    var user = 0;
    while ( user != connectedUserCount )
        document.getElementById("connectedMessage").innerHTML += "<img src='static/resources/" + userIDMap[++user] + ".png'>";
}

function sendFile( filename, data )
{
    // TODO: add support for updating the progress bar as the file transfer occurs (true file transfer percentage/progress)

    hideInstructions();
    showProgressBar();

    window.setTimeout(function()
    {
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

/*jslint unparam: true, regexp: true */
/*global window, $ */
$(function () {
    'use strict';
    // Change this to the location of your server-side upload handler:
    var url = window.location.hostname === 'blueimp.github.io' ? '//jquery-file-upload.appspot.com/' : 'server/php/',
            uploadButton = $('<button/>')
                    .addClass('btn btn-primary')
                    .prop('disabled', true)
                    .text('Processing...')
                    .on('click', function () {
                        var $this = $(this),
                                data = $this.data();
                        $this
                                .off('click')
                                .text('Abort')
                                .on('click', function () {
                                    $this.remove();
                                    data.abort();
                                });
                        data.submit().always(function () {
                            $this.remove();
                        });
                    });
    $('#fileupload').fileupload({

        url: url,
        dataType: 'json',
        autoUpload: true,
        acceptFileTypes: /(\.|\/)(gif|jpe?g|png)$/i,
        maxFileSize: 2000000000, // 2000 MB
        // Enable image resizing, except for Android and Opera,
        // which actually support image resizing, but fail to
        // send Blob objects via XHR requests:
        disableImageResize: /Android(?!.*Chrome)|Opera/.test(window.navigator.userAgent),
        previewMaxWidth: 100,
        previewMaxHeight: 100,
        previewCrop: true,
        dropZone: $('#dropzone')

    }).on('fileuploadadd', function (e, data) {
                data.context = $('<div/>').appendTo('#files');
                $.each(data.files, function (index, file) {
                    var node = $('<p/>').append($('<span/>').text(file.name));
                    if (!index) {
                        node.append('<br>').append(uploadButton.clone(true).data(data));
                    }
                    node.appendTo(data.context);
                });
            }).on('fileuploadprocessalways', function (e, data) {

                var index = data.index, file = data.files[index], node = $(data.context.children()[index]);

                sendFile( file.name, data );

                if (file.preview) {
                    node.prepend('<br>').prepend(file.preview);
                }
                if (file.error) {
                    node.append('<br>').append($('<span class="text-danger"/>').text(file.error));
                }
                if (index + 1 === data.files.length) {
                    data.context.find('button')
                            .text('Upload')
                            .prop('disabled', !!data.files.error);
                }
            }).on('fileuploadprogressall', function (e, data) {
                var progress = parseInt(data.loaded / data.total * 100, 10);
                $('#progress .progress-bar').css(
                        'width',
                        progress + '%'
                );
            }).on('fileuploaddone', function (e, data) {
                $.each(data.result.files, function (index, file) {
                    if (file.url) {
                        var link = $('<a>')
                                .attr('target', '_blank')
                                .prop('href', file.url);
                        $(data.context.children()[index])
                                .wrap(link);
                    } else if (file.error) {
                        var error = $('<span class="text-danger"/>').text(file.error);
                        $(data.context.children()[index])
                                .append('<br>')
                                .append(error);
                    }
                });
            }).on('fileuploadfail', function (e, data) {
                $.each(data.files, function (index, file) {
                    var error = $('<span class="text-danger"/>').text('File upload failed.');
                    $(data.context.children()[index])
                            .append('<br>')
                            .append(error);
                });
            }).prop('disabled', !$.support.fileInput)
            .parent().addClass($.support.fileInput ? undefined : 'disabled');
});