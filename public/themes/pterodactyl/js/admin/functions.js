/**
 * Avtix Theme - Admin Panel Utility Functions
 * Fixed and enhanced version with proper error handling
 */

'use strict';

/**
 * Get URL query parameter by name
 * @param {string} name - Parameter name
 * @returns {string|null} Parameter value or null
 */
function getUrlParam(name) {
    try {
        var results = new RegExp('[\\?&]' + name + '=([^&#]*)').exec(decodeURIComponent(window.location.href));
        if (results === null) {
            return null;
        }
        return results[1] || null;
    } catch (e) {
        console.error('Error parsing URL parameter:', e);
        return null;
    }
}

/**
 * Get page name from URL
 * @param {string} url - URL to parse
 * @returns {string} Page name without extension
 */
function getPageName(url) {
    try {
        var index = url.lastIndexOf('/') + 1;
        var filenameWithExtension = url.substr(index);
        var filename = filenameWithExtension.split('.')[0];
        return filename;
    } catch (e) {
        console.error('Error getting page name:', e);
        return '';
    }
}

/**
 * Parse query parameters from current URL
 * @returns {Object} Query parameters as key-value pairs
 */
function parseQueryParameters() {
    var queryParameters = {};
    var queryString = location.search.substring(1);
    var re = /([^&=]+)=([^&]*)/g;
    var m;

    while ((m = re.exec(queryString)) !== null) {
        try {
            queryParameters[decodeURIComponent(m[1])] = decodeURIComponent(m[2]);
        } catch (e) {
            console.warn('Error decoding query parameter:', m[1]);
        }
    }

    return queryParameters;
}

var queryParameters = parseQueryParameters();

$(document).on('click', "a[data-toggle='tab']", function() {
    try {
        queryParameters.tab = $(this).attr('href').substring(1);
        var newUrl = location.pathname + '?' + $.param(queryParameters);
        window.history.pushState(null, null, newUrl);
    } catch (e) {
        console.error('Error updating tab URL:', e);
    }
});

$(document).ready(function() {
    var tabParam = getUrlParam('tab');
    if (tabParam !== null) {
        var $tab = $('.nav.nav-tabs a[href="#' + tabParam + '"]');
        if ($tab.length) {
            $tab.tab('show');
        }
    }
});
