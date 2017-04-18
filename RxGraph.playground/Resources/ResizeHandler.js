function handleResize(simulation, d3Svg) {
  function resize() {
    var size = d3Svg.node().getBoundingClientRect();

    simulation
      .force('center').x(size.width/2).y(size.height/2);

    d3Svg
      .attr("viewBox", "0 0 " + size.width + " " + size.height)
      .attr("preserveAspectRatio", "xMidYMid meet");
    simulation.restart();
  }

  resize();

  d3.select(window).on('resize', resize);
}
