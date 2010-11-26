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

function playDirectory(fullPath) {
  return function() {
    $.post("/playdir", { path: "/media/" + fullPath });
  };
}

function addSubtree(parentEl, subtree) {
  var dirUl = $("<ul/>");
  parentEl.append(dirUl);

  var fileUl = $("<ul/>");
  parentEl.append(fileUl);

  // add subdirectories to the displayed tree
  $.each(subtree.directories, function(i, full_path) {
    var sub = $("<li class='directory'/>");

    var playDir = $("<span class='cmd playAll'>all</span>");
    playDir.click(playDirectory(full_path));
    sub.append(playDir);

    sub.append(" ");

    var name = $("<span class='dirName'/>");
    name.text(full_path.split("/").pop());
    name.click(toggleExpandDir(full_path));
    sub.append(name);

    dirUl.append(sub);
  });

  // add files to the displayed tree
  $.each(subtree.files, function(i, list) {
    var full_path = list[0];
    var playcount = list[1];

    var sub = $("<li class='file cmd'/>");

    var name = $("<span/>");
    name.text(full_path.split("/").pop());
    sub.append(name);

    if(playcount) {
      var pc = $("<span class='playcount'/>");
      pc.text(playcount);
      sub.append(pc);

      if(playcount == 0)
        sub.addClass('unplayed');
    }

    fileUl.append(sub);

    name.click(playFile(full_path));
  });
}

$(document).ready(function(){
  addSubtree($("#tree"), rootTree);
});
