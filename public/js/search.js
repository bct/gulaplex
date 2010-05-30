function playFile(fullPath) {
  return function() {
    $.post("/playfile", { path: fullPath });
  };
}

$(document).ready(function() {
  $("#search").click(function() {
    var qInput = $(this).prev("input[name='q']");

    $.getJSON('/search?q=' + qInput.val(), function(data) {
      var resultsUl = $("#results");

      resultsUl.children().remove();

      $.each(data, function(i, path) {
        var li = $("<li class='file cmd'/>");
        li.text(path);
        li.click(playFile(path));
        resultsUl.append(li);
      });
    });

    return false;
  });
});
