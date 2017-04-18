function handleDragDrop(simulation, d3Container) {
  function dragSubject() { return simulation.find(d3.event.x, d3.event.y); }

  function dragStarted() {
    if (!d3.event.active) simulation.alphaTarget(0.3).restart();
    d3.event.subject.fx = d3.event.subject.x;
    d3.event.subject.fy = d3.event.subject.y;
  }

  function dragMove() {
    d3.event.subject.fx = d3.event.x;
    d3.event.subject.fy = d3.event.y;
  }

  function dragEnded() {
    if (!d3.event.active) simulation.alphaTarget(0);
    d3.event.subject.fx = null;
    d3.event.subject.fy = null;
  }

  d3Container
    .call(d3.drag()
      .container(d3Container.node())
      .subject(dragSubject)
      .on('start', dragStarted)
      .on('drag', dragMove)
      .on('end', dragEnded));
}