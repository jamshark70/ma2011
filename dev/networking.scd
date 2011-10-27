

~mungo = "192.168.3.61";

~mungoClient = NetAddr(~mungo, 57120);
~mungoServer = NetAddr(~mungo, 57110);

u.remove;
u = SimpleController(BP(\ml)).put(\allPtsReceived, e { |m|
	~mungoServer.sendMsg(\c_setn, 5, 5, m.centroid.x, m.centroid.y, m.anglePoint.theta,
		m.anglePoint.rho, m.normmag);
});

z = Server(\mungo, ~mungoServer, ServerOptions.new);
z.makeGui;
z.startAliveThread;
z.stopAliveThread;

~mungoClient.sendMsg('/hello');





n = NetAddr("192.168.3.61", 57120);

n.sendMsg('/hello');

o = OSCFunc({ |msg| msg.postcs }, '/mungo');



"你好".postln;

~master => MCG(7);

g = GenericGlobalControl(\thresh, nil, 0.5);
g => VP(2);


~trig.free;
~trig = ~master.play({ |thresh = 0.5|
	var	in = CompanderD.ar(SoundIn.ar(0), thresh: -14.dbamp, slopeBelow: 10, slopeAbove: 1),
	fft = FFT(LocalBuf(512, 1), in),
	trig = Onsets.kr(fft, thresh);
	// trig = Schmidt.ar(in, -17.dbamp, 0.15),
	// pb = PlayBuf.ar(1, b, 1, trig, TRand.kr(0, BufFrames.kr(b) - 100000, trig)),
	// eg = EnvGen.kr(Env.perc(0.01, 0.5, -1.5), trig);
	// PulseCount.kr(trig).poll(trig);
	SendReply.kr(trig, '/keystroke');
}, [thresh: g]);

[1011, 1013].do(s.sendMsg(\n_free, _))

o.free;
o = OSCFunc({ |msg| ~master.play(\bufGrainPan, [start: rand(b.numFrames - 100000), time: rrand(0.1, 2.5), bufnum: b, pan: 1.0.rand2, rate: exprand(1.0, 3.0)]); }, '/keystroke', s.addr);

o.free;
o = OSCFunc({ |msg| a.set(\t_trig, 1) }, '/keystroke', s.addr);



a.free;

a.trace;

and i type normally, it only picks up some
now a much lower threshold

a = ~master.play {
	var sig = SoundIn.ar(0);
	sig = CompanderD.ar(sig, thresh: -14.dbamp, slopeBelow: 10, slopeAbove: 1);
	Out.ar(2, sig);
};


a.free;


(play: { ~action.envirGet.value },
flash: {
	fork({
		~window.visible = true;
		// ~window.bounds = ~bounds;
		~sustain.wait;
		~window.visible = false;
		// ~window.bounds = ~bounds;
	}, AppClock)
},
close: { defer(e { ~window.close }) }) => ProtoEvent(\flash);


GUI.swing;
SwingOSC.default.boot;

w = Window(\xyz, Rect(600, 100, 400, 250)).front;
StaticText(w, w.view.bounds.insetBy(5, 5)).align_(\center).string_("insert joke here");
w.visible = false;

p = (Pbind(
	\window, w,
	\bounds, w.bounds,
	\delta, Pseg(
		Pseq(#[0.8, 0.08, 0.8], 1),
		6,
		\sin
	),
	\sustain, Pkey(\delta) * Env(#[0.05, 0.95, 0.05], #[6, 6], \sin),
	\action, \flash
) ++ Pbind(
	\window, w,
	\delta, Pn(1, 1),
	\action, \close
)).play(protoEvent: ProtoEvent(\flash).copy);

p.stop;

fork({
	var e = Env([0, 1, 0], [0.5, 0.5], \sin);
	(0, 0.05 .. 1.0).do { |i|
		w.alpha = e[i];
		0.1.wait;
	};
	w.close;
}, AppClock);



w = Window(\xyz, Rect(600, 100, 400, 250)).front;
StaticText(w, w.view.bounds.insetBy(5, 5)).align_(\center).string_("insert joke here");

w.bounds;

w.visible = false;

w.bounds;

w.visible = true;

w.bounds;



Window.allWindows[1..].do(_.close)
w.alpha_(0.1);



// pretty but can't display chinese
{ |text, time(2), font(Font("Liberation Mono", 24)), margin(10)|
	fork({
		var textsize = GUI.stringBounds(text, font),
		sbounds = Window.screenBounds,
		w = Window("flash",
			Rect(
				sbounds.right - textsize.right - (margin*2),
				50, textsize.right + (margin*2), textsize.bottom + (margin*2)
			).postcs,
			border: false
		);
		w.background_(Color.black).alwaysOnTop_(true);
		StaticText(w, w.view.bounds)
		.align_(\center)
		.font_(font)
		.stringColor_(Color.white)
		.string_(text);
		w.front;
		// "wmctrl -b add,above -r 'flash'".unixCmd(nil, false);
		time.wait;
		w.close;
	}, AppClock);
} => Func(\flash);

{ |text, time(4)|
	"notify-send -t % '%'".format((time*1000).asInteger, text).unixCmd(nil, false);
} => Func(\flash);

\flash.eval("test");

f = File(thisProcess.nowExecutingPath.dirname +/+ "test.txt", "r");
t = f.readAllString;
f.close;

\flash.eval(t);

"notify-send -t 2000 '%'".format(t).unixCmd;
