function seekPercent(percent) {
  $.post("/playtime", { pos: percent + "%"});
}

function updatePercent() {
  $.get('/playtime', {}, function(data, textStatus) {
    $("#slider").slider('option', 'value', data);
  });

  setTimeout(updatePercent, updatePeriod);
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

  setTimeout(updatePercent, updatePeriod);

  addSubtree($("#tree"), rootTree);
});
