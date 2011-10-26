

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


w = Window(\xyz, Rect(600, 100, 400, 250)).front;
StaticText(w, w.view.bounds.insetBy(5, 5)).align_(\center).string_("你好");
fork({
	var e = Env([0, 1, 0], [0.5, 0.5], \sin);
	(0, 0.05 .. 1.0).do { |i|
		w.alpha = e[i];
		0.1.wait;
	};
	w.close;
}, AppClock);

"你好".postln;

~master => MCG(7);

g = GenericGlobalControl(\thresh, nil, 0.5);
g => VP(2);

a = ~master.play({ |thresh = 0.5|
	var	in = CompanderD.ar(SoundIn.ar(0), thresh: -18.dbamp, slopeBelow: 10, slopeAbove: 1),
	fft = FFT(LocalBuf(512, 1), in),
	trig = Onsets.kr(fft);
	// trig = Schmidt.ar(in, -17.dbamp, 0.15),
	// pb = PlayBuf.ar(1, b, 1, trig, TRand.kr(0, BufFrames.kr(b) - 100000, trig)),
	// eg = EnvGen.kr(Env.perc(0.01, 0.5, -1.5), trig);
	// PulseCount.kr(trig).poll(trig);
	SendReply.kr(trig, '/keystroke');
}, [thresh: g]);

o.free;
o = OSCFunc({ |msg| ~master.play(\bufGrainPan, [start: rand(b.numFrames - 100000), time: rrand(0.1, 2.5), bufnum: b, pan: 1.0.rand2, rate: exprand(1.0, 3.0)]); }, '/keystroke', s.addr);



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
