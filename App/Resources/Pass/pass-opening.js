/* Android b1e318b PassIntro.kt — opening geometry, keyframes and compositing order. */
(() => {
  const p=(t,a,d)=>Math.max(0,Math.min(1,(t-a)/d)),lerp=(a,b,k)=>a+(b-a)*k;
  function bez(x1,y1,x2,y2){return x=>{let lo=0,hi=1,t=x;for(let i=0;i<18;i++){t=(lo+hi)/2;const v=3*(1-t)**2*t*x1+3*(1-t)*t*t*x2+t*t*t;if(v<x)lo=t;else hi=t;}return 3*(1-t)**2*t*y1+3*(1-t)*t*t*y2+t*t*t;};}
  const web=bez(.16,1,.3,1),charge=bez(.7,0,.3,1),seam=bez(.7,0,.84,1);
  function at(a,k,e=web){k=Math.max(0,Math.min(1,k));for(let i=0;i<a.length-2;i+=2){if(k<=a[i+2])return lerp(a[i+1],a[i+3],e((k-a[i])/(a[i+2]-a[i])));}return a.at(-1);}
  const $=s=>document.querySelector(s);
  let back,burst,pack;
  function canvas(parent,name){const n=document.createElement('canvas');n.className=name;parent.append(n);return n;}
  function context(n,w,h){const d=devicePixelRatio||1;if(n.width!==Math.ceil(w*d)||n.height!==Math.ceil(h*d)){n.width=Math.ceil(w*d);n.height=Math.ceil(h*d);}n.style.width=w+'px';n.style.height=h+'px';const c=n.getContext('2d');c.setTransform(d,0,0,d,0,0);c.clearRect(0,0,w,h);return c;}
  function circle(c,x,y,r,fill,alpha=1){c.save();c.globalAlpha=alpha;c.fillStyle=fill;c.beginPath();c.arc(x,y,r,0,Math.PI*2);c.fill();c.restore();}
  function radial(c,x,y,r,stops){const g=c.createRadialGradient(x,y,0,x,y,r);stops.forEach(([a,b])=>g.addColorStop(a,b));return g;}
  function packFace(t) {
    const c=context(pack,190,280);c.save();c.beginPath();c.roundRect(0,0,190,280,18);c.clip();
    const g=c.createLinearGradient(0,0,200,300);g.addColorStop(0,'#8a3a6c');g.addColorStop(1,'#3d1430');c.fillStyle=g;c.fillRect(0,0,190,280);
    c.strokeStyle='#ffffff38';c.lineWidth=2;c.stroke();
    function text(v,y,size,color,spacing=0,face='Kakao',height=size*1.5,bold=false){c.font=`${bold?800:400} ${size}px ${face}`;c.letterSpacing=spacing+'px';c.textAlign='center';c.fillStyle=color;const m=c.measureText(v);c.fillText(v,95,y+(height-m.fontBoundingBoxAscent-m.fontBoundingBoxDescent)/2+m.fontBoundingBoxAscent);c.letterSpacing='0px';}
    text('WEDDING PLANT',26,8,'#e8a6cd',1.6);text('OUR NEXT CHAPTER',243.5,7,'#e8a6cd',1.4);
    c.save();c.translate(72,78.75);c.scale(46/24,46/24);c.strokeStyle='#e8a6cd';c.lineWidth=1.6;c.lineCap=c.lineJoin='round';c.stroke(new Path2D('M12 21V10C5 11 3 7 3 3c6 0 9 3 9 7 0-6 4-8 9-7 0 6-4 8-9 7'));c.restore();
    text('준비',134.75,28,'#ffe1ef',-1.68,'Round',34,true);text('패스',168.75,28,'#ffe1ef',-1.68,'Round',34,true);
    const shine=c.createLinearGradient(0,0,190,280);shine.addColorStop(0,'#ffffff00');shine.addColorStop(.5,'#ffffff14');shine.addColorStop(1,'#ffffff00');c.fillStyle=shine;c.fillRect(0,0,190,280);
    const bright=t<2250?at([0,1,.7,1.1,1,2],t/2250,charge):2;c.save();c.globalCompositeOperation='lighter';c.globalAlpha=bright-1;c.fillStyle=g;c.fillRect(0,0,190,280);c.restore();
    const k=p(t,800,1450),o=at([0,0,.45,.6,1,1],k,seam),height=280*Math.min(1,at([0,.03,.45,.6,1,1.5],k,seam));
    for(const [w,a,color] of [[20,.22,'#ffd9ed'],[8,.45,'#ffd9ed'],[2,1,'#fff']]){c.globalAlpha=o*a;c.fillStyle=color;c.fillRect(95-w/2,(280-height)/2,w,height);}c.restore();
  }
  function render(t,top,bottom) {
    const root=$('.pack-stage');
    if(!back){back=canvas(root,'native-opening-back');burst=canvas(root,'native-opening-burst');pack=canvas($('.sealed-pack'),'native-pack');}
    const w=innerWidth,h=innerHeight,usable=h-top-bottom,cy=top+usable*.4,cx=w/2,long=Math.max(w,h),cardW=Math.min(w*.5,usable*.4/(280/190),220),scale=cardW/190;
    const c=context(back,w,h);c.fillStyle='#0b090f';c.fillRect(0,0,w,h);
    const glow=radial(c,cx,cy,long*.75,[[0,'#56213e'],[.58,'#160d18'],[1,'#160d1800']]);circle(c,cx,cy,long*.75,glow,lerp(1,.55,p(t,2350,900)));
    if(t>=1800){const k=p(t,1800,3400),a=at([0,0,.15,.7,.3,1,1,.32],k)*(1-p(t,5200,300)),r=w*.7*at([0,.1,.15,.5,.3,1.4,1,1],k);circle(c,cx,cy,r,radial(c,cx,cy,r*Math.SQRT2,[[0,'#fff2e6f2'],[.22,'#edbaad73'],[.42,'#bd548940'],[.68,'#bd548900'],[1,'#bd548900']]),a);}
    if(t>=1900){const k=p(t,1900,3600),rays=at([0,0,.15,.35,.25,.9,1,.16],k),grow=at([0,.3,.25,1.1,1,1],k);c.save();c.translate(cx,cy);c.rotate(t/90000*Math.PI*2);c.scale(grow,grow);c.beginPath();for(let i=0;i<18;i++){const a=i*20*Math.PI/180,b=a+1.8*Math.PI/180;c.moveTo(0,0);c.lineTo(Math.cos(a)*long,Math.sin(a)*long);c.lineTo(Math.cos(b)*long,Math.sin(b)*long);c.closePath();}c.globalAlpha=Math.min(1,rays/.16);c.fillStyle=radial(c,0,0,long,[[0,'#fff0d700'],[.08,'#fff0d71a'],[.6,'#fff0d700'],[1,'#fff0d700']]);c.fill();c.globalAlpha=Math.max(0,Math.min(1,(rays-.16)/.74));c.fillStyle=radial(c,0,0,long,[[0,'#fff0d700'],[.06,'#fff0d733'],[.5,'#fff0d700'],[1,'#fff0d700']]);c.fill();c.restore();}
    for(let i=0;i<14;i++)circle(c,w*((i*.618)%1),h*((i*.377+.07)%1),1+i%2,'#fff',.35*(.5+.5*Math.sin(t/9000*Math.PI*4+i))**3);
    if(t>=2180&&t<3530){const k=p(t,2180,1350),e=web(k),a=at([0,0,.12,1,1,0],k),r=155*lerp(.4,5,e),tilt=Math.cos(lerp(30,65,e)*Math.PI/180);for(const [lw,color,alpha]of[[10,'#eda6c7',a*.5],[2,'#ffd9ed',a]]){c.globalAlpha=alpha;c.lineWidth=lw;c.strokeStyle=color;c.beginPath();c.ellipse(cx,cy,r,r*tilt,0,0,Math.PI*2);c.stroke();}c.globalAlpha=1;}
    const f=context(burst,w,h);
    for(let i=0;i<48;i++){const k=p(t,2200+(i%6)*35,2000);if(k>0&&k<1){const a=at([0,0,.15,1,1,0],k),dist=(170+(i%7)*55)*web(k),angle=i/48*Math.PI*2,x=cx+Math.cos(angle)*dist,y=cy+Math.sin(angle)*dist;circle(f,x,y,1.6,'#eda6c7',.45*a);circle(f,x,y,.7,'#ffd9ed',a);}}
    if(t>=2170&&t<3020){f.globalAlpha=at([0,0,.12,.95,1,0],p(t,2170,850));f.fillStyle=radial(f,cx,cy,Math.hypot(cx,Math.max(cy,h-cy)),[[0,'#fffef8'],[.23,'#fff0d7'],[.5,'#f7d5e499'],[.85,'#f7d5e400'],[1,'#f7d5e400']]);f.fillRect(0,0,w,h);f.globalAlpha=1;}
    packFace(t);
    const k=t/2250,e=web(p(t,2250,450)),x=t<2250?at([0,0,.7,0,.85,-3,.93,3,1,0],k,charge):0,y=t<2250?at([0,45,.25,0,.7,-4,1,-4],k,charge):lerp(-4,0,e),rot=t<2250?at([0,-30,.25,-8,.7,6,.85,-5,.93,4,1,0],k,charge):0,s=t<2250?at([0,.85,.25,1,.7,1.04,.85,1.06,.93,1.07,1,1.08],k,charge):lerp(1.08,2.25,e);
    const node=$('.sealed-pack');node.style.cssText=`left:${cx-95+x}px;top:${cy-140+y}px;width:190px;height:280px;padding:0;border:0;border-radius:18px;background:none;box-shadow:none;translate:none;animation:none;opacity:${t<2250?at([0,0,.25,1,1,1],k,charge):1-e};transform:perspective(8064px) rotateY(${rot}deg) scale(${scale*s});filter:blur(${t<2250?0:30*e}px)`;
    const anchor=$('.card-anchor'),entry=$('.card-entry'),reveal=p(t,2350,1500),d=t/9000*Math.PI*2;
    anchor.style.setProperty('width',cardW+'px','important');anchor.style.setProperty('height',cardW*280/190+'px','important');anchor.style.left='50%';anchor.style.setProperty('top',(cy+3*Math.sin(d))+'px','important');anchor.style.transform='none';anchor.style.visibility=t>=2350?'visible':'hidden';
    $('.card-perspective').style.width=cardW+'px';$('.card-perspective').style.height=cardW*280/190+'px';
    entry.style.cssText=`animation:none!important;opacity:${at([0,0,.3,1,1,1],reveal)};transform:perspective(8064px) translateY(${at([0,80,.75,-12,1,0],reveal)}px) rotateY(${at([0,70,.75,-6,1,0],reveal)}deg) rotateZ(${at([0,0,.75,-3,1,0],reveal)+1.2*Math.sin(d*1.3)}deg) scale(${at([0,.65,.75,1.05,1,1],reveal)})`;
    $('.card-rotor').style.transform='none';$('.card-tilt').style.transform='none';$('.card-floating').style.transform='none';PassDemos.card($('.card-face.front'),t);
    const copyTop=(cy+cardW*280/190/2+18+h-bottom-28-139.5)/2,caption=$('.pack-caption');caption.style.setProperty('top',copyTop+'px','important');caption.style.bottom='auto';caption.style.opacity='1';
    for(const [selector,start]of[['h2',3050],['p',3300]]){const n=caption.querySelector(selector),v=web(p(t,start,800));n.style.cssText=`animation:none!important;opacity:${v};transform:translateY(${18*(1-v)}px)`;}
    const button=$('.pack-continue');button.style.opacity=p(t,3900,250);button.disabled=t<3900;
    $('.pack-loading').style.cssText=`animation:none;position:absolute;left:0;bottom:0;width:${100*p(t,0,3900)}%;height:3px;opacity:${1-p(t,3900,400)};background:#efa4c7;transform:none`;
    document.body.classList.toggle('opening-controls-ready',t>=3900);
  }
  window.PassOpening={render};
})();
