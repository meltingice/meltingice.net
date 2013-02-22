---
layout: post
title: Implementing an ORM in Coffeescript - Part 1
---

For the past week and a half, I have been working on and off on refactoring my [node-activerecord](https://github.com/meltingice/node-activerecord/tree/refactoring) project. For those of you who aren't familiar with the concept of "active record", it's a way to map an object directly to a database entry. It exposes an object-relational mapping (ORM) that makes it incredibly simple to work with the database.

Since a lot goes into developing a full ORM (and because I'm in the middle of developing node-activerecord as I write this), I decided to break down these posts into multiple parts. In this first part, I want to share a cool trick that involves implementing the attribute getters and setters.

If you've ever used [Rails](http://rubyonrails.org), then you are likely familiar with that ActiveRecord implementation. It works something like this:

{% highlight ruby %}
# models/user.rb
class User < ActiveRecord::Base

# Creation
user = User.new
user.name = "Ryan"
user.save

# Reading
user = User.find(1)
puts user.name
{% endhighlight %}

Pretty straightforward stuff, but how do we implement something similar to that in Coffeescript? We want to be able to do this:

{% highlight coffeescript %}
class User extends Model
  # Let's not worry about managing the schema yet
  fields: ['name']

# Creation
user = new User()
user.name = "Ryan"
user.save()

# Reading (asynchronous, of course)
user = User.find 1, (err, user) ->
  console.log user.name
{% endhighlight %}

Your first thought might be that you can simply set the `name` property on `user` since it's an object. While true, this isn't very helpful. In order to know what attributes have been altered, and in order to do some other important stuff such as trigger Observer methods, we need `user.name` to really be a method.

Lucky for us, there is a nifty method that was introduced with ECMAScript 5 (back in 2009!) that lets us do exactly that called `Object.defineProperty`. It lets us implement actual getter and setter methods for any property on an object. Here's how it is implemented in node-activerecord:

{% highlight coffeescript %}
for field in [@primaryKey].concat(@fields) then do (field) =>
  Object.defineProperty @, field,
    enumerable: true
    configurable: false
    get: -> @readAttribute(field)
    set: (val) ->
      # We don't allow the primary index to be set via
      # accessor method.
      return if field is @primaryKey
      if @readAttribute(field) isnt val
        val = @applyAttributeFilter(field, val)
        @writeAttribute(field, val)
        @dirtyKeys[field] = true
{% endhighlight %}

Let's walk through this line by line.

First, we loop over every defined field for the model. The primary key is always created and automatically defined as `id` unless specified otherwise (code not shown). The special thing about this loop, however, is that it actually executes a function for each iteration in order to create a closure. The `do` keyword in Coffeescript is used for exactly this. Because we're defining the properties in a loop, we need to make sure that `field` in the following lines refers to the correct value, or else it will always refer to the last item in the loop once the loop is finished executing. If it helps you picture it, it roughly looks like this in Javascript:

{% highlight js %}
var _fn = function (field) {
  // Here field is guaranteed to be the correct value
  // because variables have function scope in JS.
  Object.defineProperty(/* etc */)
};

for (var i = 0; i < fields.length; i++) {
  var field = fields[i];
  _fn(field);
}
{% endhighlight %}

Next, we call our `Object.defineProperty` method. The first argument tells it that we want to bind the getter/setter functions to *this* object (the Model). The next argument is an object of options. Setting `enumerable: true` and `configurable: false` guarantees that the property will show up during enumeration (looping over object properties) and that the property cannot be deleted from the Model.

Finally the getter and setter functions are defined. The getter is extremely simple. It returns the value from the `@data` object (via `@readAttribute`), which is where we actually store all attributes of the model.

The setter, however, does some important operations. First, we don't allow the primary key to be manually set. By convention, the primary key is an automatically generated and monotonically increasing number. Next, if the value of the attribute has changed, we apply a filter function from the Observer, if it exists. The Observer is simply an object that contains callback methods, which are named by convention. Updating the `name` attribute calls the `filterName` function in the Observer. This gives us an opportunity to perform operations on the value of the attribute before it is set. A good example of this would be to strip invalid characters. Finally, we use the setter method to easily track what attributes have changed and need to be persisted to the database by updating a `dirtyKeys` object.

## Near Future

Using `Object.defineProperty` is an incredibly useful method, but let's all agree that it's messy and gross. Luckily, the next version of ECMAScript (codenamed Harmony) defines *Proxies*. A proxy will let you define and override most of the default behavior of an object in Javascript. This means that, instead of having to call `Object.defineProperty` for every field, we can define a proxy that intercepts the reading and writing of any attribute on the model. It would look sometihng like this:

{% highlight coffeescript %}
handler =
  get: (target, name) -> target.readAttribute(name)
  set: (target, field, value) ->
    return if field is target.primaryKey
    if target.readAttribute(field) isnt value
      value = target.applyAttributeFilter(field, value)
      target.writeAttribute(field, value)
      target.dirtyKeys[field] = true

return new Proxy User, handler
{% endhighlight %}

The future of Javascript certainly looks bright as it gains more meta-programming abilities, and the node-activerecord project will continue to update with the language. Keep an eye out for the next part of this series of posts.