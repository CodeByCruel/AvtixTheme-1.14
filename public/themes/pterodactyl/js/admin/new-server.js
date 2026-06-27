/**
 * Avtix Theme - New Server Creation
 * Fixed and enhanced with proper error handling and accessibility
 */

'use strict';

$(document).ready(function() {
    $('#pNestId').select2({
        placeholder: 'Select a Nest',
    }).change();

    $('#pEggId').select2({
        placeholder: 'Select a Nest Egg',
    });

    $('#pPackId').select2({
        placeholder: 'Select a Service Pack',
    });

    $('#pNodeId').select2({
        placeholder: 'Select a Node',
    }).change();

    $('#pAllocation').select2({
        placeholder: 'Select a Default Allocation',
    });

    $('#pAllocationAdditional').select2({
        placeholder: 'Select Additional Allocations',
    });
});

var lastActiveBox = null;
$(document).on('click', function(event) {
    if (lastActiveBox !== null) {
        lastActiveBox.removeClass('box-primary');
    }
    lastActiveBox = $(event.target).closest('.box');
    lastActiveBox.addClass('box-primary');
});

/**
 * Escape HTML to prevent XSS
 * @param {string} str - String to escape
 * @returns {string} Escaped string
 */
function escapeHtml(str) {
    if (str === null || str === undefined) {
        return '';
    }
    var div = document.createElement('div');
    div.appendChild(document.createTextNode(String(str)));
    return div.innerHTML;
}

$('#pNodeId').on('change', function() {
    var currentNode = $(this).val();
    if (!Pterodactyl || !Pterodactyl.nodeData) {
        console.warn('Pterodactyl.nodeData not available');
        return;
    }

    $.each(Pterodactyl.nodeData, function(i, v) {
        if (v.id == currentNode) {
            $('#pAllocation').html('').select2({
                data: v.allocations,
                placeholder: 'Select a Default Allocation',
            });
            updateAdditionalAllocations();
        }
    });
});

$('#pNestId').on('change', function() {
    var nestId = $(this).val();
    if (!Pterodactyl || !Pterodactyl.nests) {
        console.warn('Pterodactyl.nests not available');
        return;
    }

    var eggs = _.get(Pterodactyl.nests, nestId + '.eggs', []);
    $('#pEggId').html('').select2({
        data: $.map(eggs, function(item) {
            return {
                id: item.id,
                text: item.name,
            };
        }),
    }).change();
});

$('#pEggId').on('change', function() {
    var nestId = $('#pNestId').val();
    var eggId = $(this).val();

    if (!Pterodactyl || !Pterodactyl.nests) {
        console.warn('Pterodactyl.nests not available');
        return;
    }

    var parentChain = _.get(Pterodactyl.nests, nestId, null);
    var objectChain = _.get(parentChain, 'eggs.' + eggId, null);

    if (!objectChain) {
        console.warn('Egg not found for ID:', eggId);
        return;
    }

    var images = _.get(objectChain, 'docker_images', {});
    $('#pDefaultContainer').html('');
    var keys = Object.keys(images);
    for (var i = 0; i < keys.length; i++) {
        var opt = document.createElement('option');
        opt.value = images[keys[i]];
        opt.textContent = keys[i] + ' (' + images[keys[i]] + ')';
        $('#pDefaultContainer').append(opt);
    }

    var startup = _.get(objectChain, 'startup');
    if (!startup) {
        startup = _.get(parentChain, 'startup', 'ERROR: Startup Not Defined!');
    }
    $('#pStartup').val(startup);

    var packs = _.get(objectChain, 'packs', []);
    $('#pPackId').html('').select2({
        data: [{ id: 0, text: 'No Service Pack' }].concat(
            $.map(packs, function(item) {
                return {
                    id: item.id,
                    text: item.name + ' (' + item.version + ')',
                };
            })
        ),
    });

    var variableIds = {};
    $('#appendVariablesTo').html('');
    var variables = _.get(objectChain, 'variables', []);

    $.each(variables, function(i, item) {
        variableIds[item.env_variable] = 'var_ref_' + item.id;

        var isRequired = (item.required === 1) ? '<span class="label label-danger">Required</span> ' : '';
        var dataAppend = ' \
            <div class="form-group col-sm-6"> \
                <label for="var_ref_' + escapeHtml(item.id) + '" class="control-label">' + isRequired + escapeHtml(item.name) + '</label> \
                <input type="text" id="var_ref_' + escapeHtml(item.id) + '" autocomplete="off" name="environment[' + escapeHtml(item.env_variable) + ']" class="form-control" value="' + escapeHtml(item.default_value) + '" /> \
                <p class="text-muted small">' + escapeHtml(item.description) + '<br /> \
                <strong>Access in Startup:</strong> <code>{{' + escapeHtml(item.env_variable) + '}}</code><br /> \
                <strong>Validation Rules:</strong> <code>' + escapeHtml(item.rules) + '</code></small></p> \
            </div> \
        ';
        $('#appendVariablesTo').append(dataAppend);
    });

    if (typeof serviceVariablesUpdated === 'function') {
        serviceVariablesUpdated(eggId, variableIds);
    }
});

$('#pAllocation').on('change', function() {
    updateAdditionalAllocations();
});

function updateAdditionalAllocations() {
    var currentAllocation = $('#pAllocation').val();
    var currentNode = $('#pNodeId').val();

    if (!Pterodactyl || !Pterodactyl.nodeData) {
        console.warn('Pterodactyl.nodeData not available');
        return;
    }

    $.each(Pterodactyl.nodeData, function(i, v) {
        if (v.id == currentNode) {
            var allocations = [];
            for (var j = 0; j < v.allocations.length; j++) {
                var allocation = v.allocations[j];
                if (allocation.id != currentAllocation) {
                    allocations.push(allocation);
                }
            }
            $('#pAllocationAdditional').html('').select2({
                data: allocations,
                placeholder: 'Select Additional Allocations',
            });
        }
    });
}

function initUserIdSelect(data) {
    $('#pUserId').select2({
        ajax: {
            url: '/admin/users/accounts.json',
            dataType: 'json',
            delay: 250,
            data: function(params) {
                return {
                    filter: { email: params.term },
                    page: params.page,
                };
            },
            processResults: function(data) {
                return { results: data };
            },
            cache: true,
        },
        data: data,
        escapeMarkup: function(markup) { return markup; },
        minimumInputLength: 2,
        templateResult: function(data) {
            if (data.loading) return escapeHtml(data.text);
            return '<div class="user-block"> \
                <img class="img-circle img-bordered-xs" src="https://www.gravatar.com/avatar/' + escapeHtml(data.md5) + '?s=120" alt="User Image"> \
                <span class="username"> \
                    <a href="#">' + escapeHtml(data.name_first) + ' ' + escapeHtml(data.name_last) + '</a> \
                </span> \
                <span class="description"><strong>' + escapeHtml(data.email) + '</strong> - ' + escapeHtml(data.username) + '</span> \
            </div>';
        },
        templateSelection: function(data) {
            return '<div> \
                <span> \
                    <img class="img-rounded img-bordered-xs" src="https://www.gravatar.com/avatar/' + escapeHtml(data.md5) + '?s=120" style="height:28px;margin-top:-4px;" alt="User Image"> \
                </span> \
                <span style="padding-left:5px;"> \
                    ' + escapeHtml(data.name_first) + ' ' + escapeHtml(data.name_last) + ' (<strong>' + escapeHtml(data.email) + '</strong>) \
                </span> \
            </div>';
        }
    });
}
