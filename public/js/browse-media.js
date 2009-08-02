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
      li.text(file);
      playlist.append(li);
    });
  });

  setTimeout(updateStatus, updatePeriod);
}

function toggleExpandDir(fullPath) {
  return function() {
    var parent = $(this).parent();
    var subtree = parent.children("ul");

    if(subtree.length != 0) {
      subtree.remove();
    } else {
      var url = "/media/" + fullPath;

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

$(document).ready(function(){
  $("#slider").slider({
    value: sliderPos,
    slide: function(event, ui) { seekPercent(ui.value); }
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
