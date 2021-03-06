import format.swf.Data;
import format.abc.Data;

class Test {

	static var frame = 1;

	static function main() {
		#if neko
		var file = Sys.args()[0];
		var bytes = sys.io.File.getBytes(file);
		decode(bytes);
		#else
		var l = new flash.net.URLLoader();
		l.dataFormat = flash.net.URLLoaderDataFormat.BINARY;
		l.addEventListener(flash.events.Event.COMPLETE,function(_) {
			decode(haxe.io.Bytes.ofData(l.data));
		});
		l.load(new flash.net.URLRequest("file.swf"));
		#end
	}

	static function decode( bytes : haxe.io.Bytes ) {
		var t = haxe.Timer.stamp();
		var i = new haxe.io.BytesInput(bytes);
		var reader = new format.swf.Reader(i);
		var h = reader.readHeader();
		var tags = reader.readTagList();
		i.close();
		trace( haxe.Timer.stamp() - t );
		trace(h);
		#if neko
		for( t in tags ) {
			var str = tagStr(t);
			#if neko
			neko.Lib.println(str);
			#else
			trace(str);
			#end
		}
		#end
		var o = new haxe.io.BytesOutput();
		var w = new format.swf.Writer(o);
		w.writeHeader(h);
		for( t in tags )
			w.writeTag(t);
		w.writeEnd();
		#if neko
		var file = sys.io.File.write("file2.swf",true);
		file.write(o.getBytes());
		file.close();
		#end
	}

	static function poStr(data:PlaceObject) {
		var b = new StringBuf();
		if( data.cid != null )
			b.add("#"+data.cid+" ");
		b.add("@"+data.depth+" ");
		b.addChar("<".code);
		if( data.matrix != null ) {
			b.add("T");
			if( data.matrix.rotate != null ) b.add("R");
			if( data.matrix.scale != null ) b.add("S");
		}
		if( data.color != null )
			b.add("C");
		if( data.ratio != null )
			b.add("X");
		if( data.instanceName != null )
			b.add("I");
		if( data.clipDepth != null )
			b.add("D");
		if( data.events != null )
			b.add("E");
		if( data.filters != null )
			b.add("F"+data.filters.length);
		if( data.blendMode != null )
			b.add("B");
		if( data.bitmapCache != null )
			b.add("@");
		b.addChar(">".code);
		var str = b.toString();
		if( data.filters != null )
			for( f in data.filters )
				str += "\n    "+Std.string(f);
		return str;
	}

	static function tagStr(t) {
		return switch(t) {
		case TShape(sid,_):
			"Shape #"+sid;
		case TBinaryData(cid,data):
			"BinaryData #"+cid+" ["+data.length+"]";
		case TShowFrame:
			"ShowFrame "+frame++;
		case TBackgroundColor(color):
			"BgColor "+StringTools.hex(color,6);
		case TClip(cid,frames,tags):
			var old = frame;
			frame = 1;
			var str = "Clip #"+cid+":"+frames;
			for( t in tags )
				str += "\n  "+tagStr(t);
			frame = old;
			return str;
		case TUnknown(id,data):
			"0x"+StringTools.hex(id,2)+" ["+data.length+"]";
		case TPlaceObject3(data):
			"PlaceObject3 "+poStr(data);
		case TPlaceObject2(data):
			"PlaceObject2 "+poStr(data);
		case TRemoveObject2(depth):
			"RemoveObject2 @"+depth;
		case TFrameLabel(label,anchor):
			"FrameLabel "+label+(anchor ? " [ANCHOR]" : "");
		case TDoInitActions(cid,data):
			"DoInitActions #"+cid+" ["+data.length+"]";
		case TActionScript3(data,context):
			var str = "AS3"+((context == null) ? "" : " #"+context.id+" '"+context.label+"'");
			var reader = new format.abc.Reader(new haxe.io.BytesInput(data));
			var ctx = reader.read();
			// decode bytecode
			var opcodes = 0;
			for( f in ctx.functions ) {
				var ops = format.abc.OpReader.decode(new haxe.io.BytesInput(f.code));
				opcodes += ops.length;
				var bytes = new haxe.io.BytesOutput();
				var opw = new format.abc.OpWriter(bytes);
				for( o in ops )
					opw.write(o);
				f.code = bytes.getBytes();
			}
			str += " "+opcodes+" ops";
			var output = new haxe.io.BytesOutput();
			new format.abc.Writer(output).write(ctx);
			var bytes = output.getBytes();
			if( bytes.compare(data) != 0 )
				throw "ERROR";
			str;
		case TSandBox(_):
			"Sandbox";
		case TSymbolClass(sl):
			var str = "Symbols";
			for( s in sl )
				str += "\n  #"+s.cid+" "+s.className;
			str;
		case TBitsLossless2(l),TBitsLossless(l):
			"BitsLossless [#"+l.cid+","+l.width+"x"+l.height+":"+l.color+","+l.data.length+" bytes]";
		case TBitsJPEG(id, _):
			"BitsJPEG #" + id;
		case TSound(s):
			var desc = switch( s.data ) {
			case SDMp3(_,data):
				var i = new haxe.io.BytesInput(data);
				var mp3 = new format.mp3.Reader(i).read();
				(", frames: " + mp3.frames.length);
			default:
				" (format not yet supported) ";
			};
			"Sound [#"+s.sid+","+s.format+","+s.rate+desc+"]";
		default:
			format.swf.Tools.dumpTag(t);
		};
	}

}
