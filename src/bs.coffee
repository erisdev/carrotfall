# Gets the element-relative position of the mouse pointer from a MouseEvent.
# @param [MouseEvent] event the event.
# @return [{[Number] x, [Number] y}] the mouse poiner's relative position.
mouse = (event) ->
  {left, top} = event.target.getBoundingClientRect()
  {clientX, clientY} = event
  {x:clientX - left, y:clientY - top}

projector = new THREE.Projector
vector = new THREE.Vector3

# Gets the object and surface coordinates under the mouse pointer from a MouseEvent.
# @param [MouseEvent] event the event.
# @param [THREE.Camera] camera the camera to project from.
# @param [Array<THREE.Object3D>] objects the list of objects to query.
mouse3D = (event, camera, objects) ->
  {width, height} = event.target
  {x, y} = mouse(event)
  vector.set(2 * x / width - 1, -(2 * y / height - 1), 0.5)
  raycaster = projector.pickingRay(vector.clone(), camera)
  raycaster.intersectObjects(objects)[0]

window.bs = {mouse, mouse3D}
