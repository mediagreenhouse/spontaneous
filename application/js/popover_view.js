console.log("Loading PopoverView...");


Spontaneous.PopoverView = (function($, S) {
	var dom = S.Dom;
	var PopoverView = new JS.Class({
		initialize: function() {
			// should be over-ridden by subclasses
			// who should call #super
		},
		set_manager: function(manager) {
			this.manager = manager;
		},
		view: function() {
			// construct view
		},
		width: function() {
			return 400;
		},
		position_from_event: function(event) {
			return {top: event.clientX, left: event.clientY};
		},
		close: function() {
			this.manager.close();
		},
		before_close: function() {
		},
		do_close: function() {
		},
		after_close: function() {
		}
	});
	return PopoverView;
})(jQuery, Spontaneous);


