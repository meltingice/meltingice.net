---
layout: post
title: Plucking Multiple Database Columns in Rails 3
---

The problem: you have a large result set that you want to return, but you don't need full blown ActiveRecord models for each result. In fact, doing so would likely bring the Ruby process to a crawl. Instead, you just need a few attributes in an array plucked from each result.

If you only want to fetch a single column from a query, you can use the normal `pluck` method.

{% highlight ruby %}
# Fetch all post IDs whose category is 'cats'
Post.where(category: 'cats').pluck(:id)
{% endhighlight %}

If you want to fetch more than one attribute, you unfortunately can't use pluck.

{% highlight ruby %}
Post.where(category: 'cats').pluck(:id, :created_at)
#=> ArgumentError: wrong number of arguments (2 for 1)
{% endhighlight %}

Passing an Array to `pluck` also doesn't work and produces an invalid SQL query. Next, you might be tempted to try this:

{% highlight ruby %}
Post.where(category: 'cats').map { |p| {id: p.id, created_at: p.created_at} }
{% endhighlight %}

Let's assume that you're an incredibly prolific writer about cats. In your time, you've written hundreds of thousands of articles about cats. It's gotten to the point that you might want to see a therapist. Anyways, the code above is bad. It will create a Post object for every single database result that is found, and then pull the data from each one by one. It's basically going to suck the life out of your server.

Next you might be tempted to try something tricky like this:

{% highlight ruby %}
Post.where(category: 'cats').select([:id, :created_at])
{% endhighlight %}

Ah ha, this will only query for the two attributes that are needed! Well, actually it creates hundreds of thousands of incomplete objects and will still suck the life out of your server. Still not good enough.

## Solution

The solution actually came from inspecting the source of the `pluck` method. One of the great advantages of open-source software.

{% highlight ruby %}
# File activerecord/lib/active_record/relation/calculations.rb, line 179
def pluck(column_name)
  if column_name.is_a?(Symbol) && column_names.include?(column_name.to_s)
    column_name = "#{connection.quote_table_name(table_name)}.#{connection.quote_column_name(column_name)}"
  else
    column_name = column_name.to_s
  end

  relation = clone
  relation.select_values = [column_name]
  klass.connection.select_all(relation.arel).map! do |attributes|
    klass.type_cast_attribute(attributes.keys.first, klass.initialize_attributes(attributes))
  end
end
{% endhighlight %}

If you look towards the bottom of the code snippet, you'll see that ActiveRecord is using a `select_all` method under the hood. When given a AREL relation, it runs a query that selects only the attributes that are needed from the database, and then maps the results to the model.

If we pull out bits and pieces of this code, we can bypass creating the model altogether by leveraging `select_all`. The nice thing about ActiveRecord is that it lazy-loads data. This means we can build a query without touching the database.

{% highlight ruby %}
# This does not query the database yet
query = Post.where(category: 'cats').select([:id, :created_at])

# This will issue a query, but only with the attributes we selected above.
# It also returns a simple Hash, which is significantly more efficient than a
# full blown ActiveRecord model.
results = ActiveRecord::Base.connection.select_all(query)
#=> [{"id" => 1, "created_at" => 2013-02-26 01:28:08 UTC}, etc...]
{% endhighlight %}

## Integration

There are two different routes we can take in order to make this code a little prettier and integrate it into our project. First, we can extend `ActiveRecord::Relation` itself. If you're feeling ballsy, you can change it to override the original `pluck` method. The best place to put this code would be in an initializer.

{% highlight ruby %}
# pluck_all.rb
module ActiveRecord
  class Relation
    def pluck_all(*args)
      args.map! do |column_name|
        if column_name.is_a?(Symbol) && column_names.include?(column_name.to_s)
          "#{connection.quote_table_name(table_name)}.#{connection.quote_column_name(column_name)}"
        else
          column_name.to_s
        end
      end

      relation = clone
      relation.select_values = args
      klass.connection.select_all(relation.arel).map! do |attributes|
        initialized_attributes = klass.initialize_attributes(attributes)
        attributes.each do |key, attribute|
          attributes[key] = klass.type_cast_attribute(key, initialized_attributes)
        end
      end
    end
  end
end
{% endhighlight %}

{% highlight ruby %}
# post_controller.rb
Post.where(category: 'cats').pluck_all(:id, :created_at)
{% endhighlight %}

If the thought of extending ActiveRecord brings a queasy feeling to your stomach, we can also wrap this into a pretty little Concern to include in our models. It's not as clean, but it works.

{% highlight ruby %}
# multi_pluck.rb
require 'active_support/concern'

module MultiPluck
  extend ActiveSupport::Concern

  included do
    def self.pluck_all(relation, *args)
      connection.select_all(relation.select(args))
    end
  end
end
{% endhighlight %}

{% highlight ruby %}
# post.rb
class Post < ActiveRecord::Base
  include MultiPluck
  
  # ...
end
{% endhighlight %}

{% highlight ruby %}
# post_controller.rb
Post.pluck_all(Post.where(category: 'cats'), :id, :created_at)
{% endhighlight %}

## Future

Luckily, Rails 4 has multiple column plucking [built in](https://github.com/rails/rails/pull/6500), so we don't have to worry about this workaround. If you're stuck with Rails 3 though, give it a try!