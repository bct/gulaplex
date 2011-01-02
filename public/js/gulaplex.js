function seekPercent(percent) {
  $.post("/playtime", { pos: percent + "%"});
}

function setupPlaylistDragging() {
  // Initialise the table
  $("#playlist-entries").tableDnD({
    onDragStyle: { background: "red" },
    onDragStart: function(table, row) {
      stopPlaylistUpdates = true;
    },
    onDrop: function(table, row) {
      // send the new playlist
      var entries = [];

      // TODO: figuring out the new order is going to be problematic.
      // not sure how to signal to sinatra the new order.
      // maybe i should attach the full path to each table row?
      alert(row);
      alert(table.tBodies[0].rows);

      $.post("/playlist", jQuery.param({ "entries[]": [1,2] }), function(data, textStatus) {
        stopPlaylistUpdates = false;
      }, "json");
    }
  });
}

function updateStatus() {
  $.getJSON('/status', function(data) {
    $("#slider").slider('option', 'value', data.percentPos);
    $("#playing").text(data.playing);

    /* update the playlist */
    if( !window.stopPlaylistUpdates ) {
      var playlist = $("#playlist-entries");
      playlist.empty();

      $.each(data.playlist, function(i, file) {
        var tr = $("<tr/>");

        var td0 = $("<td/>");
        td0.text(file);
        tr.append(td0);

        playlist.append(tr);
      });

//      setupPlaylistDragging();
    }

    setTimeout(updateStatus, updatePeriod);
  });
}

function playFile(fullPath) {
  return function() {
    $.post("/playfile", { path: fullPath });
  };
}

function appendFile(appendTo, text, playcount, clickCallback) {
  var li = $("<li class='file cmd'/>");

  var name = $("<span/>");
  name.text(text);
  li.append(name);

  if(playcount) {
    var pc = $("<span class='playcount'/>");
    pc.text(playcount);
    li.append(pc);

    if(playcount == 0)
      li.addClass('unplayed');
   }

  appendTo.append(li);

  name.click(clickCallback);
}

function asyncButton(buttonSelector, postUrl) {
  $(buttonSelector).click(function() {
    $.post(postUrl);
    return false;
  });
}

$(document).ready(function(){
  $("#slider").slider({
    value: sliderPos,
    slide: function(event, ui) { seekPercent(ui.value); }
  });

  asyncButton('#clear', '/clear');
  asyncButton('#pause', '/pause');
  asyncButton('#stop',  '/stop');
  asyncButton('#next',  '/forward');
  asyncButton('#sub-select',    '/sub-select');
  asyncButton('#audio-select',  '/audio-select');

  $("#playlist-youtube").click(function() {
    var urlInput = $(this).prev("input[name='url']");
    var htmlUrl = urlInput.val();

    urlInput.val('');

    $.post('/playlist-youtube', { url: htmlUrl })
    return false;
  });

  setTimeout(updateStatus, updatePeriod);

//  setupPlaylistDragging();
});
