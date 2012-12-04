---
---

class m.ClockDataSource.Now extends m.ClockDataSource
  updateFrequency: 1000

  ping: ->
    date = new Date()
    [date.getHours(), date.getMinutes(), date.getSeconds()]