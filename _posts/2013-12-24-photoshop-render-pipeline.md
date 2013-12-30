---
layout: post
title: Building a Photoshop Render Pipeline
---

While working on building previews layer-by-layer with [PSD.rb](https://github.com/layervault/psd.rb), it quickly became obvious that a more formal rendering pipeline would be necessary in order to avoid out of control spaghetti code and rendering errors. This article serves as a general spec and outline for how this rendering pipeline will work.

Keeping the render pipeline efficient is going to be difficult with Ruby's memory management, but by formalizing it into distinct concerns, it should be easier to implement parts of it with psd-native over time for speed improvements. Please note, this is a *living document* that will likely be updated during the development of the pipeline.

## Important Considerations

There are some interesting properties and edge cases in PSD documents that make rendering previews tricky.

### Passthru Blending

Groups in PSD documents can have a "passthru" blending mode. This is the default blending mode, and essentially denotes that the layer group is nothing more than an organization tool. All of the layers within the group are applied directly to the last active canvas.

### Group Opacity

That said, groups with passthru blending can still have an adjusted opacity. When in passthru mode, this opacity is applied to the children layers when they are painted to the active canvas.

When not in passthru mode, the opacity is applied when the group canvas is blended with the parent canvas. Here's a visual example of how passthru group opacity affects the appearance of the render (thanks Allan):

![](http://i.imgur.com/zjqHvPj.png)

### Tree Hierarchy

The rendering pipeline is actually not a simple linear process, but instead a depth-first tree iteration. The "root" node in PSD documents is implied, but all top-level layers and groups can be considered the children of this invisible root node. This is already reflected in the tree node structure exposed by PSD.rb with `psd.tree`.

If you have a PSD structure like this:

{% highlight yaml %}
- Group A
  - Layer A
  - Group B
    - Layer B
  - Layer C
- Layer D
{% endhighlight %}

Then the pipeline iteration will look like this:

1. Paint Layer D to root canvas
2. Discover Group A and create Group A canvas
3. Paint Layer C to Group A canvas
4. Discover Group B and create Group B canvas
5. Paint Layer B to Group B canvas
6. Paint Group B to Group A canvas
7. Paint Layer A to Group A canvas
8. Paint Group A to root canvas

Remember that layers and groups lower in the list have a lower z-index on the canvas, which is why we begin from the bottom. I believe this is the reason why the layers and groups are stored in reverse order in the PSD file format. PSD.rb reverses the order for usability purposes, but the order can just as easily be reversed back for the rendering pipeline.

## Pipeline Spec

While the steps outlined above are a simplified overview of how to walk the tree, Photoshop is a complex piece of software that offers **many** different tools that complicate things. Between masks, layer styles, and blending modes (not to mention blending modes for individual layer styles), things get a bit hairy. It would be beneficial to be able to render pieces of the document such as a single layer group, so this consideration needs to be kept in mind as well.

### The Active Canvas

At all times there is an "active canvas" that is the target for painting. Since we are dealing with depth-first tree iteration, this canvas lives at the top of a canvas stack.

When a new group **with passthru blending** is encountered, the active canvas does not change. When a new group **with a blend mode** is encountered, a new canvas is pushed onto the stack and becomes the active canvas. When the group iteration is finished, the active canvas is popped from the stack and painted to the new active canvas. The bottom of the stack always contains the root node canvas, which is created at the start of the render pipeline.

### Rendering a Layer

Rendering a layer consists of multiple steps that must be followed in the correct order.

1. Fetch the layer image data. This is a 1-dimensional array of RGBA pixel values encoded as an unsigned 32-bit integer in the format RRGGBBAA.
2. Apply the mask(s) to the image data, if any are present. Photoshop allows both a vector mask and a "user" (non-vector) mask to be present. Typically vector masks are applied to create various built-in shapes like rounded rectangles.
3. Apply layer styles, if any are present. As far as I can tell, the layer styles are applied in the order listed in the Photoshop interface from top to bottom.
4. Apply group inherited opacity. The way in which this is done varies based on the closest ancestor node with an active canvas. More on this below.
5. Paint the layer to the active canvas with the given blend mode.

This process is repeated until the end of the group is reached. At that time, the layer is painted to the active canvas.

### Group Inherited Opacity

Before painting a layer to the active canvas, we have to calculate the opacity inherited from the ancestor groups of the current layer. Inherited opacity only comes from groups marked with passthru blending.

In order to calculate this, we must iterate up the tree along the ancestor nodes until we either reach the first group with a canvas (aka a non-passthru group) or the root node. During each iteration step, the calculated opacity is altered by the group opacity using the formula:

{% highlight ruby %}
# Assuming [0, 100] scale for opacity
inherited_opacity = (inherited_opacity * group_opacity) / 100
{% endhighlight %}

Obviously, this value can be cached for all layers in the group, but calculation is also fairly cheap, so it may be a non-issue. Once we hit a non-passthru group, we apply the inherited opacity to the opacity of the layer. This does not affect the layer's fill opacity, which comes into play during the painting process.

## Modules

The rendering pipeline will be broken up into the modules as follows:

### Image

Stores a reference to the pixel array of the image (as described above), and offers helper methods for manipulating the pixels.

### Blender

The blender is a module that contains a set of blending methods that only needs to know about a single foreground pixel, a background pixel, and the blend opacities.

### Mask

Given an image and a mask, the Mask module applies the mask to the image by adjusting the image alpha channels. The image maintains it's original size. Because some masks can extend beyond the bounds of the layer, it will need to be aware of this to avoid errors.

### LayerStyles

Given a set of layer style instructions and an Image, apply each applicable layer style to the image data. Each layer style will be its own class such that it only needs to know how to perform a single layer style application. The main LayerStyles class will act as a manager for applying all the styles.

### Renderer

The main class that runs the pipeline. The renderer, given any PSD::Node inherited object, will run the pipeline to produce the final image data. The final image data can be given to ChunkyPNG for easy saving or further manipulation.

{% highlight ruby %}
renderer = Renderer.new(node).render!
renderer.to_png
{% endhighlight %}

The renderer will also include a concern that is responsible for calculating the inherited opacity of a layer.