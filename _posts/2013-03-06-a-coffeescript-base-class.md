---
layout: post
title: A Coffeescript Base Class
---

I'll be the first to admit that I'm an organizational freak when it comes to code. Yet, every time I work with a NodeJS based project, I end up frustrated that I can't organize my code in a cleaner fashion. NodeJS's require system completely isolates every file from one another, so to speak, so I always find myself tempted to write in a single-file monolithic fashion that makes my eye twich in self-restraint.

I've been putting together a base class that many of my Coffeescript classes extend in order to aid organization. It was kickstarted by [The Little Book on Coffeescript](http://arcturo.github.com/library/coffeescript/03_classes.html), and I've continued to add more methods to it. While this problem and solution isn't exclusive to Coffeescript, its syntax and class construct allows for an incredibly clean solution. This solution also isn't exclusive to NodeJS, but I find it's the most practical and helpful in that environment.

{% highlight coffeescript %}      
moduleKeywords = ['extended', 'included']

exports.Module = class Module
  # Extend the base object itself like a static method
  @extends: (obj) ->
    for key, value of obj when key not in moduleKeywords
      @[key] = value

    obj.extended?.apply(@)
    @

  # Include methods on the object prototype
  @includes: (obj) ->
    for key, value of obj when key not in moduleKeywords
      # Assign properties to the prototype
      @::[key] = value

    obj.included?.apply(@)
    @

  # Add methods on this prototype that point to another method
  # on another object's prototype.
  @delegate: (args...) ->
    target = args.pop()
    @::[source] = target::[source] for source in args

  # Create an alias for a function
  @aliasFunction: (to, from) ->
    @::[to] = (args...) => @::[from].apply @, args

  # Create an alias for a property
  @aliasProperty: (to, from) ->
    Object.defineProperty @::, to,
      get: -> @[from]
      set: (val) -> @[from] = val

  # Execute a function in the context of the object, and pass
  # a reference to the object's prototype.
  @included: (func) -> func.call @, @::
  {% endhighlight %}

If you're a Ruby user, than a lot of this might look familiar to you. So what does the Module class allow us to do? This code is taken directly from my [node-activerecord](https://github.com/meltingice/node-activerecord) project:

{% highlight coffeescript %}
{Module} = require './module'

class Model extends Module
  @extends  require('./tablenaming').static
  @includes require('./tablenaming').members

  @extends  require('./querying').static
  @includes require('./querying').members
  @includes require('./properties')
  @includes require('./relations')
  @includes require('./events')
{% endhighlight %}

This allows me to cleanly and easily organize the majority of the code for the Model class in other files. The Module class also allows you to do things like:

{% highlight coffeescript %}
{Module} = require './module'

class Foo extends Module
  log: -> console.log 'hi!'

class Bar extends Module
  @delegate 'log', Foo
  @aliasFunction 'b', 'a'
  @aliasProperty 'd', 'c'

  c: 'test'
  a: -> console.log 'a'

bar = new Bar()
bar.log() # calls Foo::log()
bar.b()   # calls Bar::a()
bar.d     # gets Bar::c
{% endhighlight %}

I've setup [a repository](https://github.com/meltingice/coffeescript-module) for the Module class if you would like to contribute. Otherwise, if you have any ideas or suggestions, shoot me a message on [Twitter](http://twitter.com/meltingice).