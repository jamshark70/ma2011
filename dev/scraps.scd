BP(\arp).alwaysReset;
BP(\arp).v[\preparePlay].postcs
BP(\arp).resp.inspect
BP(\arp).model

BP(\arp).prevAngle

BP(\ml).dependants.insp

BP(\arp).magThresh = 0.3;
BP(\arp).angleThresh = 0.6;

BP(\arp).restEvent = (freq: #[], delta: 1, length: 1, gate: 1);

BP(\arp).makePattern = { // |pt, i|
		~numEvents = ~calcNumEvents.()/*.(pt, i)*/;  // bah, tired of passing everything as args
		DebugPbind(
			\mode, ~modePat.()/*.(pt, i)*/,
			\x, ~xPat.()/*.(pt, i)*/,
			\y, ~yPat.()/*.(pt, i)*/,
			\freq, ~freq.()/*.(pt, i)*/,
			\mod_ratio, ~mod_ratio.()/*.(pt, i)*/,
			\mod_lev, ~mod_lev.()/*.(pt, i)*/,
			\quantize, ~quantize.()/*.(pt, i)*/,
			\delta, ~delta.()/*.(pt, i)*/.collect { |dur, ev|
				var	rounded = min(~pquant, dur.round(~pquant)) - (thisThread.beats % ~pquant);
				if(rounded < ~pquant) { rounded = rounded + ~pquant };
				dur.blend(rounded, ev[\quantize])
			},
			\length, ~length.()/*.(pt, i)*/,
			\gate, ~gate.()/*.(pt, i)*/,
			\pan, ~pan.()/*.(pt, i)*/
		)/*.collect { |ev|
			#[x, y, freq].collect(ev[_]).debug("x, y, freq");
			ev
		}*/
	};

BP(\arp).magDecay = 0.63095734448019;
BP(\arp).currentMag = 0;
BP(\arp).respond = {
	var diff = ~model.anglePoint.theta - ~prevAngle,
	temp;
	if(diff.inclusivelyBetween(-pi, pi).not) { diff = (2pi - diff).wrap(-pi, pi) };
	~angleI = (~angleI + 1) % 5;
	~angleDiffs[~angleI] = diff;
	~prevAngle = ~model.anglePoint.theta;
	if(~model.normmag > ~currentMag) {
		~currentMag = ~model.normmag;
	} {
		~currentMag = ~currentMag * ~magDecay;
	};
	// heavier lifting only if we pass the threshold test
	if((~players.size < ~maxPlayers) and: { ~currentMag >= ~magThresh }) {
		temp = ~angleDiffs.copy;
		temp.remove(temp.minItem);
		temp.remove(temp.maxItem);
		if(temp.every(_.inclusivelyBetween(~angleThresh.neg, ~angleThresh))) {
			~addStream.(~makePattern.(), ~pquant).debug("fired");
		};
	};
};

BP(\arp).chords;
BP(\arp).changeChords;

BP(\arp).quantize = Pfunc({ ~model.centroid.y * 0.5 + 0.5 });

BP(\arp).delta = { Pexprand(0.2, 0.9, ~numEvents) };
BP(\arp).pquant

TempoClock.default.gui;

BP(\arp).maxPlayers = 4;
BP(\arp).players.size

BP(\arp).preparePlay = {
		~angleDiffs = 0 ! 5;
		~angleI = 0;
		~prevAngle = 0;
		~changeChordModeStream ?? { ~makeStreamForKey.(\changeChordMode) };
		if(~chords.isNil) { ~changeChords.() };
		~resp = SimpleController(~model).put(\allPtsReceived, e { ~respond.() });
	};

BP(\arp).v[\quantize].postcs

BP(\arp).useGui = { |vpi| ~syncMax => VP(vpi) };


VC(\pl).v.trace

VC(\pl).env.cb[0].plotWavetable

BP(\arp).cbufMap = #[7.9, 0, -3.2].asSpec;
BP(\arp).car_buf = Pfunc({
	~cbufMap.map(~model.centroid.y * 0.5 + 0.5) + VC(\pl).env.cb.first.bufnum
}).trace;

BP(\arp).use { ~addStream.(~makePattern.(), 0.25) };

BP(\arp).maxPlayers = 1;

BP(\arp).cbufMap.map((0.0, 0.01 .. 1.0)).plot2;




// not so hot anyway
a = m.play {
	var p = MouseX.kr(0, 0.1, 0, 0.1) + Rand(0.0, 0.8),
	v = MouseY.kr(0, 1, 0, 0.1),
	// muladd is because of a stupid bug
	point = LFDNoise1.kr(MulAdd(v, 7.5, 0.5), v * 0.03, p),
	fft = PV_BufRd(LocalBuf(1024), c, point);
	(IFFT(fft) ! 2).value(UGen.buildSynthDef.children.do(_.postln))
};

a.trace

a.free;

MouseY.findRespondingMethodFor(\madd)

MouseY.kr * 1 + 2




~receiver.free;
~receiver = OSCFunc({ |msg| msg.postcs; \flash.eval(msg[1], msg[2]) }, '/mungo');

\flash2.eval("you there?");

\flash.eval("you don't need Max/M$$$$P".escapeChar($$));
\flash.eval("you don't need Mac O$$$$X".escapeChar($$));

\mungo.eval("hello");

f = { |time, replyAddr, recvPort, msg| msg.postcs };
thisProcess.recvOSCfunc = thisProcess.recvOSCfunc.addFunc(f);

thisProcess.recvOSCfunc = thisProcess.recvOSCfunc.removeFunc(f);

NetAddr.localAddr.sendMsg("/test");
