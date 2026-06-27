/**
 * Avtix Theme - Minecraft EULA Handler
 * Fixed and enhanced with SweetAlert2 compatibility and error handling
 */

'use strict';

$(document).ready(function () {
    Socket.on('console', function (data) {
        if (typeof data === 'undefined' || typeof data.line === 'undefined') {
            return;
        }

        if (data.line.indexOf('You need to agree to the EULA in order to run the server') !== -1) {
            if (typeof Swal !== 'undefined') {
                Swal.fire({
                    title: 'EULA Acceptance',
                    html: 'By pressing \'I Accept\' below you are indicating your agreement to the <a href="https://account.mojang.com/documents/minecraft_eula" target="_blank" rel="noopener noreferrer">Mojang EULA</a>.',
                    icon: 'info',
                    showCancelButton: true,
                    confirmButtonText: 'I Accept',
                    cancelButtonText: 'I do not Accept',
                    showLoaderOnConfirm: true,
                    allowOutsideClick: false,
                    preConfirm: function () {
                        return $.ajax({
                            type: 'POST',
                            url: Pterodactyl.meta.saveFile,
                            headers: { 'X-CSRF-Token': Pterodactyl.meta.csrfToken },
                            data: {
                                file: 'eula.txt',
                                contents: 'eula=true'
                            }
                        }).then(function (response) {
                            return response;
                        }).catch(function (jqXHR) {
                            Swal.showValidationMessage(
                                'An error occurred: ' + (jqXHR.responseJSON?.error || 'Unknown error')
                            );
                        });
                    }
                }).then(function (result) {
                    if (result.isConfirmed) {
                        $('[data-attr="power"][data-action="start"]').trigger('click');
                        Swal.fire({
                            icon: 'success',
                            title: 'EULA Accepted',
                            text: 'The EULA for this server has been accepted, restarting server now.',
                            timer: 3000,
                            timerProgressBar: true
                        });
                    }
                });
            } else if (typeof swal !== 'undefined') {
                swal({
                    title: 'EULA Acceptance',
                    text: 'By pressing \'I Accept\' below you are indicating your agreement to the Mojang EULA.',
                    type: 'info',
                    showCancelButton: true,
                    showConfirmButton: true,
                    cancelButtonText: 'I do not Accept',
                    confirmButtonText: 'I Accept',
                    closeOnConfirm: false,
                    showLoaderOnConfirm: true
                }, function () {
                    $.ajax({
                        type: 'POST',
                        url: Pterodactyl.meta.saveFile,
                        headers: { 'X-CSRF-Token': Pterodactyl.meta.csrfToken },
                        data: {
                            file: 'eula.txt',
                            contents: 'eula=true'
                        }
                    }).done(function (data) {
                        $('[data-attr="power"][data-action="start"]').trigger('click');
                        swal({
                            type: 'success',
                            title: '',
                            text: 'The EULA for this server has been accepted, restarting server now.'
                        });
                    }).fail(function (jqXHR) {
                        var errorMsg = 'An error occurred while attempting to set the EULA as accepted.';
                        if (jqXHR.responseJSON && jqXHR.responseJSON.error) {
                            errorMsg += ' ' + jqXHR.responseJSON.error;
                        }
                        swal({
                            title: 'Whoops!',
                            text: errorMsg,
                            type: 'error'
                        });
                    });
                });
            } else {
                console.error('Neither SweetAlert2 nor SweetAlert1 is available');
            }
        }
    });
});
