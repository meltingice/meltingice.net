---
---

m.Clock = class Clock
  width: 100
  height: 100

  backgroundColor: '#d4d4d2'
  tickColor: '#a4a4a2'
  tickSize: 6
  secondHandColor: '#d74343'
  minuteHandColor: '#f8f8f2'
  hourHandColor: '#f8f8f2'
  dialColor: '#d4d4d2'
  dialStrokeColor: '#f8f8f2'
  dialRadius: 8

  constructor: (@canvas, @service) ->
    @canvas.width = @width
    @canvas.height = @height

    context = @canvas.getContext('2d')

    @scope = new paper.PaperScope()
    @scope.setup @canvas

    # HiDPI fixes
    devicePixelRatio  = window.devicePixelRatio || 1
    backingStoreRatio = context.webkitBackingStorePixelRatio ||
                        context.mozBackingStorePixelRatio ||
                        context.msBackingStorePixelRatio ||
                        context.oBackingStorePixelRatio ||
                        context.backingStorePixelRatio || 1

    ratio = devicePixelRatio / backingStoreRatio

    if devicePixelRatio isnt backingStoreRatio
      oldWidth = @canvas.width
      oldHeight = @canvas.height

      @canvas.width = oldWidth * ratio
      @canvas.height = oldHeight * ratio
      @canvas.style.width = "#{oldWidth}px"
      @canvas.style.height = "#{oldHeight}px"

      context.scale ratio, ratio

    @radius = @width / 2
    @center = new paper.Point(@radius, @radius)

    @drawBackground()
    @drawClockHands()

    paper.view.onFrame = @render

  drawBackground: ->
    circle = new paper.Path.Circle(@center, @radius)
    circle.fillColor = '#d4d4d2'

    # Tick marks
    tickMove = new paper.Point(0, @radius - 10)

    for i in [0...12]
      tick = new paper.Path.Line(@center, new paper.Point(@radius, @radius - @tickSize))
      tick.strokeColor = @tickColor
      tick.strokeWidth = 1
      tick.strokeCap = 'round'
      tick.translate tickMove
      tick.rotate i * 30, @center

  drawClockHands: ->
    @secondHand = new paper.Path.Line(@center, new paper.Point(@radius, @height / 8))
    @secondHand.strokeColor = @secondHandColor
    @secondHand.strokeWidth = 1
    @secondHand.stropeCap = 'round'

    @minuteHand = new paper.Path.Line(@center, new paper.Point(@radius, @height / 8))
    @minuteHand.strokeColor = @minuteHandColor
    @minuteHand.strokeWidth = 2
    @minuteHand.strokeCap = 'round'

    @hourHand = new paper.Path.Line(@center, new paper.Point(@radius, @height / 4))
    @hourHand.strokeColor = @hourHandColor
    @hourHand.strokeWidth = 6
    @hourHand.strokeCap = 'round'

    @clockDial = new paper.Path.Circle(@center, @dialRadius)
    @clockDial.fillColor = @dialColor
    @clockDial.strokeColor = @dialStrokeColor

  render: (event) =>
    secondRot = event.delta * 6
    minuteRot = secondRot / 60
    hourRot = minuteRot / 12

    @secondHand.rotate secondRot, @center
    @minuteHand.rotate minuteRot, @center
    @hourHand.rotate hourRot, @center
    
