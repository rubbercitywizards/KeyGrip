var activeTouch = null;

$("pre").each(function(i) {
  this.id = "preTag" + (i+1);
});

$(document.body).on('touchstart', 'pre,code', function(event) {
  if (activeTouch) { return; }

  var touch = event.touches[0];
  var node = $(touch.target).closest('pre')[0];

  if (node) {
    $(node).addClass('selecting');
    activeTouch = {
      identifier: touch.identifier,
      startX: event.pageX,
      startY: event.pageY,
      node: node
    };
  }
});

$(document.body).on('touchmove', 'pre,code', function(event) {
  if (!activeTouch) { return; }
  var touch = touchWithIdentifier(event.touches, activeTouch.identifier);
  if (!touch) { return; }

  if (Math.abs(touch.pageX - activeTouch.startX) > 10 ||
     Math.abs(touch.pageY - activeTouch.startY) > 10) {
    $(activeTouch.node).removeClass('selecting');
    activeTouch = null;
  }
});

$(document.body).on('touchcancel', 'pre,code', function(event) {
  if (activeTouch && touchWithIdentifier(event.changedTouches, activeTouch.identifier)) {
    $(activeTouch.node).removeClass('selecting');
    activeTouch = null;
  }
});

$(document.body).on('touchend', 'pre,code', function(event) {
  if (!activeTouch) { return; }
  var touch = touchWithIdentifier(event.changedTouches, activeTouch.identifier);
  if (!touch) { return; }

  var node = activeTouch.node;
  $(node).addClass('selected').removeClass('selecting');
  activeTouch = null;

  pasteCodeWithID(node.id);
});

function touchWithIdentifier(touches, identifier)
{
  for (var i = 0; i < touches.length; i++) {
    var touch = touches[i];
    if (touch.identifier === identifier) { return touch; }
  }
}

function pasteCodeWithID(id)
{
  location.href = "keygrip:///paste/" + id;
}

function pastedCodeWithID(id)
{
  setTimeout(function() {
    $("#" + id).removeClass('selected').removeClass('selecting');
  }, 100);
}

function contentForCodeWithID(id)
{
  return $("#" + id).text();
}

