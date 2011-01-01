function toggleExpandDir(fullPath) {
  return function() {
    var parent = $(this).parent();
    var subtree = parent.children("ul");

    if(subtree.length != 0) {
      subtree.remove();
    } else {
      var url = escape(unescape(encodeURIComponent("/media/" + fullPath)));

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
    var fullPath  = list[0];
    var playcount = list[1];

    var baseName  = fullPath.split("/").pop();

    appendFile(fileUl, baseName, playcount, playFile(fullPath))
  });
}

$(document).ready(function(){
  addSubtree($("#tree"), rootTree);
});
