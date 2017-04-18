function createGraph(parent, data) {
  
  var colorScale = d3.scaleOrdinal(d3.schemeCategory20);

  var graph = parent
    .append('svg')
    .classed('graph', true);

  /* Defs for arrow marker */

  var arrowId = parent.attr('id') + '-arrow';
  graph.append('defs')
    .selectAll('marker')
    .data([arrowId])
  .enter()
    .append('marker')
      .attr('id', function(d) { return d; })
      .attr('viewBox', '0 -5 10 10')
      .attr('refX', 25)
      .attr('refY', 0)
      .attr('markerWidth', 6)
      .attr('markerHeight', 6)
      .attr('orient', 'auto')
    .append('path')
      .attr('d', 'M0,-5L10,0L0,5 L10,0 L0, -5')
      .style('stroke', '#999')
      .style('opacity', '0.6');

  /* elements */
  var edges = graph.append('g').selectAll('.edge');
  var nodes = graph.append('g').selectAll('.node');

  /* Simulation */

  var simulation = d3.forceSimulation()
    .force('edges', d3.forceLink().distance(100).id(function(d) { return d.uuid; }))
    .force('charge', d3.forceManyBody())
    .force('center', d3.forceCenter());

  function onTick() {
    edges
      .attr('x1', function (d) { return d.source.x; })
      .attr('y1', function (d) { return d.source.y; })
      .attr('x2', function (d) { return d.target.x; })
      .attr('y2', function (d) { return d.target.y; });
      
    parent.selectAll('circle')
      .attr('cx', function (d) { return d.x; })
      .attr('cy', function (d) { return d.y; });
    parent.selectAll('text')
      .attr('x', function (d) { return d.x; })
      .attr('y', function (d) { return d.y; });
  }

  /* Edges */

  function refreshEdges(edgesData) {
    edges = edges.data(edgesData, function(d) { return d.from.uuid + "->" + d.to.uuid; });

    edges.exit().remove();

    var edgesEnter = edges.enter()
      .append('line')
      .classed('edge', true)
      .style('marker-end', 'url(#'+arrowId+')');

    edges = edges.merge(edgesEnter);
    simulation.force('edges').links(edgesData);
  }

  /* Edges */
  
  function refreshNodes(nodesData) {
    nodes = nodes.data(nodesData, function(d) { return d.uuid; });
    nodes.exit().remove();

    var nodeEnter = nodes.enter()
      .append('g')
      .classed('node', true);

    nodeEnter.append('circle')
      .attr('r', 8)
      .style('fill', function (d) { return colorScale(d.group); });
    nodeEnter.append('text')
      .attr('dx', 15)
      .attr('dy', '.35em')
      .text(function(d) { return d.name; });

    nodes = nodeEnter.merge(nodes);

    simulation.nodes(nodesData);
  }

  /* Start simulation */

  simulation.on('tick', onTick);

  function refresh(graphData) {
    refreshEdges(graphData.edges);
    refreshNodes(graphData.nodes);
    simulation.alpha(1).restart();
  }

  refresh(data);

  return {
    simulation: simulation,
    graph: graph,
    refresh: refresh
  }
}