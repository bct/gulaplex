$(document).ready(function() {
  $("#search").click(function() {
    var qInput = $(this).prev("input[name='q']");

    $.getJSON('/search?q=' + qInput.val(), function(data) {
      var resultsUl = $("#results");

      resultsUl.children().remove();

      $.each(data, function(i, list) {
        var      path = list[0];
        var playcount = list[1];

        var li = $("<li class='file cmd'/>");
        li.text(path);

        if(playcount) {
          var pc = $("<span class='playcount'/>")
          pc.text(playcount);
          li.append(pc);
        }

        resultsUl.append(li);

        li.click(playFile(path));
      });

      if(data.length == 0)
        resultsUl.append("<li>No results for " + qInput.val() + "!</li>");
    });

    return false;
  });
});
