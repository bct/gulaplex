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

      $("#playlist-entries").children("tr").each(function(tr) {
        alert(tr);
      });

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
    if( !window.stopPlaylistUpdates )
    {
      currentPlaylist = [];

      var playlist = $("#playlist-entries");
      playlist.empty();

      $.each(data.playlist, function(i, file) {
        var tr = $("<tr/>");

        var td0 = $("<td/>");
        td0.text(file);
        tr.append(td0);

        playlist.append(tr);

        currentPlaylist.push(file);
      });

      setupPlaylistDragging();
    }

    setTimeout(updateStatus, updatePeriod);
  });
}

function toggleExpandDir(fullPath) {
  return function() {
    var parent = $(this).parent();
    var subtree = parent.children("ul");

    if(subtree.length != 0) {
      subtree.remove();
    } else {
      var url = escape("/media/" + fullPath);

      $.getJSON(url, function(data){
        addSubtree(parent, data);
      });
    }
  };
}

function playFile(fullPath) {
  return function() {
    $.post("/playfile", { path: fullPath });
  };
}

function addSubtree(parentEl, subtree) {
  var dirUl = $("<ul/>");
  parentEl.append(dirUl);

  var fileUl = $("<ul/>");
  parentEl.append(fileUl);

  $.each(subtree.directories, function(i, full_path) {
    var sub = $("<li class='directory'/>");
    var name = $("<span/>");

    name.text(full_path.split("/").pop());
    sub.append(name);
    dirUl.append(sub);

    name.click(toggleExpandDir(full_path));
  });

  $.each(subtree.files, function(i, full_path) {
    var sub = $("<li class='file'/>");
    var name = $("<span/>");

    name.text(full_path.split("/").pop());
    sub.append(name);
    fileUl.append(sub);

    name.click(playFile(full_path));
  });
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

  addSubtree($("#tree"), rootTree);

  setupPlaylistDragging();
});
