Q.longStackSupport = yes

# Load a Collada model asynchronously.
# @param [String] name the name of the object to load.
# @param [String] url the URL of the Collada file.
# @return [Q.Promise<THREE.Mesh>] a promise that resolves to the loaded model.
loadModel = (name, url) ->
  Q.promise (resolve, reject, notify) =>
    onResolve = (collada) =>
      # blender's Collada exporter sticks objects two layers deep for some reason
      container = collada.scene.getObjectByName(name)
      model = container.children[0]
      model.name = container.name
      model.geometry.applyMatrix container.matrix
      resolve model
    (new THREE.ColladaLoader).load url, onResolve, notify

# Load a texture asynchronously.
# @param [String] url the URL of the texture.
# @return [Q.Promise<THREE.Texture>] a promise that resolves to the loaded texture.
loadTexture = (url) ->
  Q.promise (resolve, reject, notify) =>
    (new THREE.TextureLoader).load url, resolve, notify, reject

# Change the shading model of an object. This is needed because the Collada loader only appears to support Phong shading.
# @param
makeShadeless = (model) ->
  model.material = new THREE.MeshBasicMaterial(map:model.material.map, color:model.material.color, ambient:model.material.color)
  model

makeCastShadow = (model) ->
  model.castShadow = yes
  model

makeReceiveShadow = (model) ->
  model.receiveShadow = yes
  model

swapYZ = (model) ->
  (model.geometry ? model).applyMatrix (new THREE.Matrix4).makeRotationX(-Math.PI / 2)
  model

# Create a material from a texture, suitable for our art style (i.e., not shaded).
# @param [THREE.Texture] texture the texture to apply.
# @return [THREE.Material] the new material.
makeMaterial = (texture) ->
  new THREE.MeshBasicMaterial(map:texture)

# Represents a moving object in the game world.
class Entity
  constructor: (@model) ->
    @model.userData = this

  destroy: =>
    @tween?.stop()
    @model.parent?.remove @model

class Carrot extends Entity
  constructor: (model, variantMaterials) ->
    Entity.call this, model

    @model.position.set(_.random(-7, 7), 20, _.random(-7, 7))
    @model.rotation.set(_.random(0, 2 * Math.PI), _.random(0, 2 * Math.PI), _.random(0, 2 * Math.PI))
    @model.material = _.sample(variantMaterials) if Math.random() > 0.9

    @tween = new TWEEN.Tween(@model.position)
      .to({y:0}, 5000)
      .easing(TWEEN.Easing.Cubic.In)
      .onComplete(@destroy)
      .start()
    this

class Player extends Entity
  constructor: (model) ->
    Entity.call this, model
    @score = 0
  
  walkTo: (target) ->
    distance = @model.position.distanceTo(target)
    
    @model.lookAt target # TODO animate turning to face the new target?
    
    @tween?.stop()
    @tween = new TWEEN.Tween(@model.position)
      .to(target, 100 * distance)
      .start()
    this

document.addEventListener 'DOMContentLoaded', (event) =>
  canvas = document.getElementById('display')
  scoreBox = document.getElementById('score-box')
  
  renderer = new THREE.WebGLRenderer(canvas:canvas, alpha:yes)
  renderer.setClearColor 0x000000, 1
  renderer.shadowMapEnabled = yes

  scene = new THREE.Scene

  {width, height} = canvas

  camera = new THREE.PerspectiveCamera(60, width / height, 1, 1000)
  camera.position.set 0, 10, -30
  camera.lookAt new THREE.Vector3(0, 10, 0)
  scene.add camera

  ambientLight = new THREE.AmbientLight(0xFFFFFF)
  scene.add ambientLight
  
  sun = new THREE.DirectionalLight(0xFFFFFF, 1.0)
  sun.position.set 0, 25, 0
  sun.castShadow = yes
  sun.onlyShadow = yes
  sun.shadowCameraNear = 1
  sun.shadowCameraFar = 1000
  sun.shadowCameraLeft = -10
  sun.shadowCameraRight = 10
  sun.shadowCameraTop = 10
  sun.shadowCameraBottom = -10
  sun.shadowMapWidth = 1024
  sun.shadowMapHeight = 1024
  scene.add sun

  ground = do =>
    geometry = new THREE.CircleGeometry(10, 16)
    material = new THREE.MeshLambertMaterial(ambient:0xC4C0C8)
    makeReceiveShadow swapYZ new THREE.Mesh(geometry, material)
  scene.add ground

  Q.all([
    loadModel('bunny', 'assets/blockbunny.dae')
      .then(swapYZ)
      .then(makeShadeless)
      .then(makeCastShadow)
    loadModel('carrot', 'assets/carrot.dae')
      .then(swapYZ)
      .then(makeShadeless)
      .then(makeCastShadow)
    loadTexture('assets/carrotstrikehot.png').then(makeMaterial)
    loadTexture('assets/carrotstrikefrost.png').then(makeMaterial)
  ]).done ([playerModel, carrotModel, carrotMaterials...]) =>
    player = new Player(playerModel)
    scene.add player.model

    spawnCarrot = ->
      carrot = new Carrot(carrotModel.clone(), carrotMaterials)
      scene.add carrot.model
      carrot

    collectCarrots = ->
      box = (new THREE.Box3).setFromObject(player.model)
      for {userData:entity} in scene.children when entity instanceof Carrot
        if box.containsPoint(entity.model.position)
          entity.destroy()
          player.score++
          scoreBox.textContent = "Score: #{player.score}"

    canvas.addEventListener 'click', (event) => 
      event.preventDefault()
      if intersect = bs.mouse3D(event, camera, [ground])
        player.walkTo intersect.point

    countdown = 100
    do tick = (time = 0) =>
      requestAnimationFrame tick, canvas
      
      TWEEN.update time
      collectCarrots()
      if --countdown is 0
        countdown = 300
        spawnCarrot()

      renderer.render scene, camera
