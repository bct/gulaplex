function seekPercent(percent) {
  $.post("/playtime", { pos: percent + "%"});
}

function updateStatus() {
  $.getJSON('/status', function(data) {
    $("#slider").slider('option', 'value', data.percentPos);
    $("#playing").text(data.playing);

    $("#playlist ul").remove();
    var playlist = $("<ul/>");
    $("#playlist").append(playlist);
    $.each(data.playlist, function(i, file) {
      var li = $("<li/>");
      li.append(file);
      playlist.append(li);
    });
  });

  setTimeout(updateStatus, updatePeriod);
}

function toggleExpandDir() {
  var parent = $(this).parent();
  var subtree = parent.children("ul");

  if(subtree.length != 0) {
    subtree.remove();
  } else {
    var url = "/media/" + $(this).text();

    $.getJSON(url, function(data){
      addSubtree(parent, data);
    });
  }
}

function playFile() {
  var path = $(this).text();
  $.post("/playfile", { path: path });
}

function addSubtree(parentEl, subtree) {
  var dirUl = $("<ul/>");
  parentEl.append(dirUl);

  var fileUl = $("<ul/>");
  parentEl.append(fileUl);

  $.each(subtree.directories, function(i, path) {
    var sub = $("<li class='directory'/>");
    var name = $("<span/>");

    name.append(path);
    sub.append(name);
    dirUl.append(sub);

    name.click(toggleExpandDir);
  });

  $.each(subtree.files, function(i, path) {
    var sub = $("<li class='file'/>");
    var name = $("<span/>");

    name.append(path);
    sub.append(name);
    fileUl.append(sub);

    name.click(playFile);
  });
}

$(document).ready(function(){
  $("#slider").slider({
    value: sliderPos,
    stop: function(event, ui) { seekPercent(ui.value); }
  });

  $("#clear").click(function() {
    $.post('/clear');
    return false;
  });

  $("#pause").click(function() {
    $.post('/pause');
    return false;
  });

  $("#stop").click(function() {
    $.post('/stop');
    return false;
  });

  $("#next").click(function() {
    $.post('/forward');
    return false;
  });

  $("#sub-select").click(function() {
    $.post('/sub-select');
    return false;
  });

  $("#playlist-youtube").click(function() {
    var urlInput = $(this).prev("input[name='url']");
    var htmlUrl = urlInput.val();

    urlInput.val('');

    $.post('/playlist-youtube', { url: htmlUrl })
    return false;
  });
;

  setTimeout(updateStatus, updatePeriod);

  addSubtree($("#tree"), rootTree);
});
