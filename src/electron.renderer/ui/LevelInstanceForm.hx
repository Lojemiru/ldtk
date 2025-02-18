package ui;

class LevelInstanceForm {
	var editor(get,never) : Editor; inline function get_editor() return Editor.ME;
	var project(get,never) : data.Project; inline function get_project() return Editor.ME.project;
	var curWorld(get,never) : data.World; inline function get_curWorld() return Editor.ME.curWorld;

	public var jWrapper : js.jquery.JQuery;
	var level: data.Level;
	var fieldsForm : FieldInstancesForm;

	public function new(jTarget:js.jquery.JQuery, useCollapsers:Bool) {
		jWrapper = new J('<div class="levelInstanceForm"/>');
		jWrapper.appendTo(jTarget);

		level = editor.curLevel;
		var raw = JsTools.getHtmlTemplate("levelInstanceForm", { id:level.identifier });
		jWrapper.html(raw);

		// Turn collapsers into title
		if( !useCollapsers ) {
			var jCollapsers = jWrapper.find(".collapser");
			jCollapsers.each( (i,e)->{
				var jCollapser = new J(e);
				jCollapser.replaceWith('<h2>${jCollapser.text()}</h2>');
			});
		}

		// World panel "edit" shortcut
		jWrapper.find(".editFields").click( (_)->{
			new ui.modal.panel.EditLevelFieldDefs();
		});

		// Field instance form
		fieldsForm = new FieldInstancesForm();
		jWrapper.find("#levelCustomFields").replaceWith( fieldsForm.jWrapper );

		updateLevelPropsForm();
		updateFieldsForm();
	}

	public inline function isUsingLevel(l:data.Level) {
		return l!=null && level!=null && l.iid==level.iid;
	}

	public function useLevel(l:data.Level) {
		level = l;
		jWrapper.removeClass("disabled");
		updateLevelPropsForm();
		updateFieldsForm();
		checkState();
	}

	public function dispose() {
		jWrapper.remove();
		jWrapper = null;
		level = null;
		fieldsForm.dispose();
		fieldsForm = null;
	}

	public function onGlobalEvent(ge:GlobalEvent) {
		switch ge {
			case ProjectSelected:
				useLevel(editor.curLevel);

			case LevelRestoredFromHistory(l):
				if( isUsingLevel(l) )
					useLevel(l);

			case WorldDepthSelected(worldDepth):
				checkState();

			case LevelSettingsChanged(l):
				if( isUsingLevel(l) )
					updateLevelPropsForm();

			case LevelAdded(level):

			case LevelSelected(l):
				useLevel(l);

				jWrapper.show();

			case LevelRemoved(l):
				if( isUsingLevel(l) )
					jWrapper.hide();

			case WorldLevelMoved(_):
				updateLevelPropsForm();
				updateFieldsForm();

			case FieldDefSorted, FieldDefRemoved(_), FieldDefChanged(_), FieldDefAdded(_):
				updateFieldsForm();

			case LevelFieldInstanceChanged(l,fi):
				if( isUsingLevel(l) )
					updateFieldsForm();

				// Biome field changed
				var invalidatedLis = [];
				for( ld in project.defs.layers )
					if( ld.biomeFieldUid==fi.defUid ) {
						var li = l.getLayerInstance(ld);
						invalidatedLis.push(li);
					}
				if( invalidatedLis.length>0 )
					editor.ge.emit( AutoLayerRenderingChanged(invalidatedLis) );

			case _:
		}
	}

	function onFieldChange() {
		editor.ge.emit( LevelSettingsChanged(level) );
		editor.invalidateLevelCache(level);
	}

	function onLevelResized(newPxWid:Int,newPxHei:Int) {
		new LastChance( Lang.t._("Level resized"), project );
		var before = level.toJson();
		level.applyNewBounds(0, 0, newPxWid, newPxHei);
		onFieldChange();
		editor.ge.emit( LevelResized(level) );
		editor.invalidateLevelCache(level);
		editor.curLevelTimeline.saveFullLevelState();
		new J("dl#levelForm *:focus").blur();
	}


	function checkState() {
		if( level.worldDepth!=editor.curWorldDepth ) {
			// Disable
			jWrapper.addClass("disabled");
		}
		else if( jWrapper.hasClass("disabled") ) {
			// Enable
			jWrapper.removeClass("disabled");
			updateFieldsForm();
			updateLevelPropsForm();
		}
	}



	function updateLevelPropsForm() {
		ui.Tip.clear();

		var jForm = jWrapper.find("dl#levelProps");
		jForm.find("*").off();

		if( level==null ) {
			jWrapper.find(".curLevelId").text("???");
			return;
		}

		jWrapper.find(".curLevelId").text(level.identifier);

		// IID
		jForm.find("#leveliid").val(level.iid);
		jForm.find(".copyLevelIid").click(_->{
			App.ME.clipboard.copyStr(level.iid);
			N.copied();
		});

		// Level identifier
		jWrapper.find(".levelIdentifier").text('"${level.identifier}"');
		var i = Input.linkToHtmlInput( level.identifier, jForm.find("#identifier"));
		i.fixValue = (v)->project.fixUniqueIdStr(v, (id)->project.isLevelIdentifierUnique(id, level));
		i.onChange = ()->onFieldChange();
		if( level.useAutoIdentifier )
			i.disable();
		else
			i.enable();

		// Auto level identifier
		var i = Input.linkToHtmlInput( level.useAutoIdentifier, jForm.find("#useAutoIdentifier") );
		i.onChange = ()->{
			curWorld.applyAutoLevelIdentifiers();
			onFieldChange();
		}

		// World depth
		var i = Input.linkToHtmlInput( level.worldDepth, jForm.find("#worldDepth"));
		i.onChange = ()->onFieldChange();

		// Depth further
		var jDepthButton = jForm.find(".worldDepthAbove");
		jDepthButton.prop("disabled", !curWorld.canMoveLevelToDepthFurther(level));
		jDepthButton.click(_->{
			if( curWorld.moveLevelToDepthFurther(level) ) {
				onFieldChange();
				editor.selectWorldDepth(level.worldDepth);
			}
		});

		// Depth closer
		var jDepthButton = jForm.find(".worldDepthBelow");
		jDepthButton.prop("disabled", !curWorld.canMoveLevelToDepthCloser(level));
		jDepthButton.click(_->{
			if( curWorld.moveLevelToDepthCloser(level) ) {
				onFieldChange();
				editor.selectWorldDepth(level.worldDepth);
			}
		});

		// Coords
		var oldNeighbours = level.getNeighboursIids();
		var i = Input.linkToHtmlInput( level.worldX, jForm.find("#worldX"));
		i.onChange = ()->{
			onFieldChange();
			editor.ge.emit( WorldLevelMoved(level, true, oldNeighbours) );
		}
		i.fixValue = v->curWorld.snapWorldGridX(v,false);

		var i = Input.linkToHtmlInput( level.worldY, jForm.find("#worldY"));
		i.onChange = ()->{
			onFieldChange();
			editor.ge.emit( WorldLevelMoved(level, true, oldNeighbours) );
		}
		i.fixValue = v->curWorld.snapWorldGridY(v,false);

		// Size
		var tmpWid = level.pxWid;
		var tmpHei = level.pxHei;
		var e = jForm.find("#width"); e.replaceWith( e.clone() ); // block undo/redo
		var i = Input.linkToHtmlInput( tmpWid, jForm.find("#width") );
		i.setBounds(project.defaultGridSize, 4096);
		i.onValueChange = (v)->onLevelResized(v, tmpHei);
		i.fixValue = v->curWorld.snapWorldGridX(v,true);

		var e = jForm.find("#height"); e.replaceWith( e.clone() ); // block undo/redo
		var i = Input.linkToHtmlInput( tmpHei, jForm.find("#height"));
		i.setBounds(project.defaultGridSize, 4096);
		i.onValueChange = (v)->onLevelResized(tmpWid, v);
		i.fixValue = v->curWorld.snapWorldGridY(v,true);

		// Bg color
		var c = level.getBgColor();
		var i = Input.linkToHtmlInput( c, jForm.find("#bgColor"));
		i.jInput.attr("colorTag","bg");
		i.onChange = ()->{
			level.bgColor = c==project.defaultLevelBgColor ? null : c;
			onFieldChange();
		}
		var jSetDefault = i.jInput.siblings("a.reset");
		if( level.bgColor==null )
			jSetDefault.hide();
		else
			jSetDefault.show();
		jSetDefault.click( (_)->{
			level.bgColor = null;
			onFieldChange();
		});
		var jIsDefault = i.jInput.siblings("span.usingDefault").hide();
		if( level.bgColor==null )
			jIsDefault.show();
		else
			jIsDefault.hide();

		// Tags source background selector
		var jSelect = jForm.find("#bgPos");
		jSelect.empty();
		var jOpt = new J('<option value="">-- None --</option>');
		jOpt.appendTo(jSelect);
		var tagGroups = project.defs.getAllCompositeBackgroundsGroupedByTag();
		for( group in tagGroups ) {
			var jOptGroup = new J('<optgroup label="All composite backgrounds"/>');
			jOptGroup.appendTo(jSelect);
			if( tagGroups.length>1 )
				jOptGroup.attr('label', group.tag==null ? L._Untagged() : group.tag);
			for(ed in group.all) {
				var jOpt = new J('<option value="${ed.uid}">${ed.identifier}</option>');
				jOpt.appendTo(jOptGroup);
			}
		}

		jSelect.change( ev->{
			var uid = Std.parseInt( jSelect.val() );
			if( !M.isValidNumber(uid) )
				uid = null;

			var newBg = project.defs.getCompositeBackgroundDef(uid);

			function _apply() {
				level.background = newBg;

				if (newBg != null)
					level.backgroundUid = newBg.uid;
				else
					level.backgroundUid = null;

				editor.ge.emit( LevelSettingsChanged(level) );
			}

			_apply();
 		});

		if( level.background!=null ) {
			jSelect.removeClass("noValue");
			jSelect.val(level.background.uid);
		}
		else
			jSelect.addClass("noValue");

		JsTools.parseComponents(jWrapper);
	}


	function updateFieldsForm() {
		fieldsForm.use( Level(level), project.defs.levelFields, (fd)->level.getFieldInstance(fd, true) );
	}
}
