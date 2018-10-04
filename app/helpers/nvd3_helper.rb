module Nvd3Helper

  def nvd3_scorecard_histogram data
    html = "".html_safe
    script = javascript_tag do
      <<-END.html_safe

    var margin = {top: 10, right: 10, bottom: 20, left: 450},
    width  = 900 - margin.left - margin.right,
    height = 50 - margin.top - margin.bottom;
    var chart = d3.bullet()
                    .width(width)
                    .height(height);

        var svg = d3.select("#chart").selectAll("svg")
            .data(getData())
            .attr("interactive", "true")
            .attr("tooltips", "true")
            .enter().append("svg")
            .attr("class", "bullet")
            .attr("width", width + margin.left + margin.right)
            .attr("height", height + margin.top + margin.bottom)
            .append("g")
            .attr("transform", "translate(" + margin.left + "," + margin.top + ")")
            .call(chart);

        var title = svg.append("g")
            .style("text-anchor", "end")
            .attr("transform", "translate(-6," + height / 2 + ")");

        title.append("text")
            .attr("class", "title")
            .text(function(d) { return d.title; });

        title.append("text")
            .attr("class", "subtitle")
            .attr("dy", "1em")
            .text(function(d) { return d.subtitle; });

    function getData() {
      return #{data.to_json};
    };

    END
    end
    return html + script
  end

end
