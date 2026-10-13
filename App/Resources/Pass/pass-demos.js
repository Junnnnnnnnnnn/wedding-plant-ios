/* Android b1e318b PassIntro.kt: fixed 340 × 271 demonstrations, one 6600ms timeline.
   All four scenes use the same bundled fonts, assets, paths, timing and layout as Android. */
(() => {
  'use strict';
  const clamp = x => Math.max(0, Math.min(1, x));
  const progress = (t, start, duration) => clamp((t - start) / duration);
  const ease = x => 1 - Math.pow(1 - x, 3);
  const typed = (s, t, start, interval) => t < start ? '' : s.slice(0, Math.floor((t - start) / interval) + 1);
  const paths = {
    arrow: ['M5 12h14m-5-5 5 5-5 5'], check: ['m5 12 4 4L19 6'],
    photo: ['M6 3h12a3 3 0 0 1 3 3v12a3 3 0 0 1-3 3H6a3 3 0 0 1-3-3V6a3 3 0 0 1 3-3z','M7 8a2 2 0 1 0 4 0a2 2 0 1 0-4 0','m3 17 6-6 4 4 3-3 5 6'],
    grid: ['M5 4h14a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2z','M3 10h18M10 4v16M3 15h18'],
    bell: ['M6 16h12l-2-3V8a4 4 0 0 0-8 0v5Zm4 3a2 2 0 0 0 4 0'],
    sprout: ['M12 21V10C5 11 3 7 3 3c6 0 9 3 9 7 0-6 4-8 9-7 0 6-4 8-9 7'],
    download: ['M12 3v12m-4-4 4 4 4-4M4 17v4h16v-4']
  };
  for (const key of Object.keys(paths)) paths[key] = paths[key].map(p => new Path2D(p));
  const logo = new Image(), portrait = new Image(); logo.src = 'app_logo.png'; portrait.src = 'pass_invite_portrait.png';
  const ink = '#4e384c', faint = '#978792', docsLine = '#ebdfe7';
  function mount(node) {
    const canvas = document.createElement('canvas'); canvas.style.cssText = 'width:100%;height:100%;display:block';
    node.replaceChildren(canvas);
    const c = canvas.getContext('2d'); let time = 0, now = 0;
    const font = (size, bold = false) => { c.font = `${bold ? 700 : 400} ${size}px Kakao`; };
    const width = (value, size, bold = false) => { font(size, bold); return c.measureText(value).width; };
    function text(value, x, y, size, color = ink, bold = false, align = 'left', lineHeight = size * 1.5) {
      font(size, bold); c.fillStyle = color; c.textAlign = align; c.textBaseline = 'alphabetic';
      const m = c.measureText(value);
      const ascent = m.fontBoundingBoxAscent ?? size * .84, descent = m.fontBoundingBoxDescent ?? size * .22;
      c.fillText(value, x, y + (lineHeight - ascent - descent) / 2 + ascent);
    }
    function box(x, y, w, h, r, fill, stroke) {
      c.beginPath(); c.roundRect(x, y, w, h, r);
      if (fill) { c.fillStyle = fill; c.fill(); }
      if (stroke) { c.save(); c.clip(); c.strokeStyle = stroke; c.lineWidth = 2; c.stroke(); c.restore(); }
    }
    function line(x, y, w, color) { c.fillStyle = color; c.fillRect(x, y, w, 1); }
    function icon(name, x, y, size, color) {
      c.save(); c.translate(x, y); c.scale(size / 24, size / 24); c.strokeStyle = color; c.lineWidth = 1.6; c.lineJoin = c.lineCap = 'round';
      paths[name].forEach(p => c.stroke(p)); c.restore();
    }
    function appear(start, duration, dy, draw) {
      const k = ease(progress(time, start, duration)); if (!k) return;
      c.save(); c.globalAlpha *= k; c.translate(0, (1 - k) * dy); draw(); c.restore();
    }
    function popup(start, end, draw) {
      const k = time < end ? ease(progress(time, start, 250)) : 1 - progress(time, end, 200);
      if (k <= 0) return; c.save(); c.globalAlpha *= k; c.translate(0, (1 - k) * 10); draw(); c.restore();
    }
    function pulse(x, y, w, h, at, accent, draw) {
      const p = progress(time, at - 90, 260), scale = p > .001 && p < .999 ? 1 - .07 * Math.sin(p * Math.PI) : 1;
      c.save(); c.translate(x + w / 2, y + h / 2); c.scale(scale, scale); c.translate(-x - w / 2, -y - h / 2); draw();
      const ripple = progress(time, at - 60, 560);
      if (at >= 0 && ripple > .001 && ripple < .999) { c.save(); c.globalAlpha *= .32 * (1 - ripple); c.fillStyle = accent; c.beginPath(); c.arc(x + w / 2, y + h / 2, Math.min(w,h)/2 + 16 * ease(ripple), 0, Math.PI*2); c.fill(); c.restore(); }
      c.restore();
    }
    const buttonWidth = (label, leading, trailing) => width(label, 8) + 18 + (leading ? 16 : 0) + (trailing ? 15 : 0);
    function button(label, x, y, accent, at, leading, trailing, outlined = false, minWidth = 0) {
      const content = buttonWidth(label, leading, trailing), w = Math.max(content, minWidth), fg = outlined ? accent : '#fff';
      pulse(x,y,w,26,at,accent,() => {
        box(x,y,w,26,7,outlined ? '#fff' : accent,outlined ? accent+'73' : null);
        let tx = x + (w-content)/2 + 9;
        if (leading) { icon(leading,tx,y+7.5,11,fg); tx += 16; }
        text(label,tx,y+7,8,fg); tx += width(label,8);
        if (trailing) icon(trailing,tx+5,y+8,10,fg);
      }); return w;
    }
    function toast(label, at, bottom = 10) {
      const w = width(label,8)+42, x=(340-w)/2, y=271-bottom-26;
      appear(at,350,10,()=> { box(x,y,w,26,13,'#392a38'); icon('check',x+12,y+7,12,'#f2b6d8'); text(label,x+30,y+7,8,'#fff'); });
    }
    function photo(x,y,w,h,r,alpha=1) {
      if (!portrait.complete || !portrait.naturalWidth) return;
      c.save(); c.globalAlpha *= alpha; c.beginPath(); c.roundRect(x,y,w,h,r); c.clip();
      const scale=Math.max(w/portrait.naturalWidth,h/portrait.naturalHeight), pw=portrait.naturalWidth*scale, ph=portrait.naturalHeight*scale;
      c.drawImage(portrait,x+(w-pw)/2,y+(h-ph)/2,pw,ph); c.restore();
    }
    function field(label,value,placeholder,x,y,w,stroke,caret=false) {
      if (label) { text(label,x,y,7,faint); y+=13.5; }
      box(x,y,w,26,6,'#fff',stroke); text(value || placeholder,x+8,y+5.5,value ? 10 : 9,value ? ink : '#978792b3');
      if (caret) { c.fillStyle=ink; c.fillRect(x+8+width(value,10),y+7.5,1,11); }
      return y+26;
    }
    function attachment(x,y,w,done) {
      box(x,y,w,36,8,'#fff','#54374612'); box(x+8,y+5,24,26,6,'#f2e7f1'); icon('photo',x+13.5,y+11.5,13,'#a34b80');
      text('웨딩홀 계약서.jpg',x+40,y+5,9); text(done?'플랜에 함께 저장돼요':'첨부 중…',x+40,y+18.5,7,faint);
      if(done)icon('check',x+w-21,y+11.5,13,'#a34b80');
      else { box(x+40,y+31,w-48,3,1.5,'#ecdeea'); box(x+40,y+31,(w-48)*progress(time,3350,1150),3,1.5,'#a34b80'); }
    }
    function documents() {
      const accent='#a34b80';
      c.save(); c.globalAlpha *= 1-progress(time,5300,250);
      field('제목',typed('웨딩홀 계약',now,200,130),'어떤 지출인가요?',12,42,316,docsLine,now>=200&&now<=1350&&Math.floor(now/330)%2===0);
      const statY=88.5, statW=154.5;
      for(const [x,label,value,unit] of [[12,'일자','10월 24일',''],[173.5,'금액','1,200','만 원']]) {
        box(x,statY,statW,35.5,6,'#fff',docsLine); text(label,x+8,statY+5,7,faint); text(value,x+8,statY+15.5,10,ink,true);
        if(unit)text(' '+unit,x+8+width(value,10,true),statY+20,7,faint,true);
      }
      const dy=132;
      box(12,dy,316,82,9,'#ffffffb3'); text('서류',21,dy+12.5,10,ink,true); text('사진·PDF',21+width('서류',10,true)+5,dy+14.75,7,faint);
      const bw=buttonWidth('서류 올리기','photo'); button('서류 올리기',319-bw,dy+7,accent,1500,'photo',null,true);
      if(now<3250) { icon('photo',21,dy+51.5,11,faint); text('계약서·영수증·사진을 이 플랜에 첨부해요',37,dy+51,8,faint); }
      else appear(3250,300,8,()=>attachment(21,dy+39,298,now>=4500));
      text('첨부한 서류도 함께 저장돼요',12,241.75,7,faint);
      button('플랜 저장하기',328-buttonWidth('플랜 저장하기',null,'arrow'),234,accent,5000,null,'arrow'); c.restore();
      appear(5300,350,10,()=> {
        icon('check',12,43.5,12,accent); text('플랜이 등록되었어요.',29,42,10,accent,true);
        box(12,65,316,118,10,'#fff',docsLine);
        text('웨딩홀 · 카드',24,77,7,faint); text('웨딩홀 계약',24,90.5,13,ink,true);
        text('10월 24일',24,116,8,faint); text('1,200만 원',316,116,8,ink,true,'right'); line(24,136,292,docsLine);
        box(24,145,24,26,6,'#f2e7f1'); icon('photo',29.5,151.5,13,accent);
        text('웨딩홀 계약서.jpg',56,146,9); text('플랜에 저장 · 두 사람이 함께 확인',56,159.5,7,faint); icon('check',303,151.5,13,accent);
      });
      popup(1700,3250,()=> {
        box(30,43,280,159.5,12,'#fff',docsLine); text('이 플랜에 첨부할 서류를 선택하세요',42,55,10,ink,true);
        for(let i=0;i<2;i++) {
          const x=42+i*132, y=79, selected=i===0&&now>=2400;
          pulse(x,y,124,75.5,i===0?2400:-1,accent,()=> {
            box(x,y,124,75.5,8,selected?'#faf0f7':'#fff',selected?accent:docsLine);
            c.save(); c.translate(x+62,y+29.5); c.rotate((i?4:-5)*Math.PI/180);
            const pw=i?31:37, grad=c.createLinearGradient(0,-21.5,0,21.5);grad.addColorStop(0,'#fff');grad.addColorStop(1,'#faf8f8');
            box(-pw/2,-21.5,pw,43,0,grad,'#d7c9ce');for(let n=0;n<3;n++) {c.fillStyle='#d8cbd2';c.fillRect(-pw/2+6,-11.5+n*7,pw-12,2);}c.restore();
            text(i?'드레스 영수증.jpg':'웨딩홀 계약서.jpg',x+62,y+57,7,ink,false,'center');
            box(x+106,y+8,14,14,7,selected?accent:'#fff',selected?accent:'#dbcbd5'); if(selected)icon('check',x+108.5,y+10.5,9,'#fff');
          });
        }
        button('선택한 서류 첨부',298-buttonWidth('선택한 서류 첨부'),164.5,accent,3000);
      });
      toast('플랜과 서류를 함께 저장했어요',5650);
    }
    function excel() {
      const accent='#588361', schedule=now>=2100;
      for(let i=0;i<2;i++) {const label=i?'일정':'예산',x=12+i*44,on=i===Number(schedule),w=width(label,9,on)+22;
        pulse(x,42.75,w,25.5,i?1900:-1,accent,()=>{box(x,42.75,w,25.5,6,on?'#dfebdc':null);text(label,x+11,48.75,9,on?'#507751':'#839581',on);});}
      button('엑셀 받기',328-buttonWidth('엑셀 받기','download'),42.5,accent,3600,'download');
      const rows=schedule?[['준비 일정','날짜','상태'],['웨딩홀 계약','10. 24','완료'],['드레스 셀렉','11. 07','예정'],['본식 촬영','05. 22','예정']]:[['준비 항목','예산','상태'],['웨딩홀','12,000,000','확정'],['스드메','5,000,000','확정'],['본식 촬영','3,000,000','예정']];
      const start=schedule?2200:200;
      rows.forEach((r,i)=>{const k=i?ease(progress(time,start+(i-1)*250,300)):1;c.save();c.globalAlpha*=k;c.translate((1-k)*8,0);const y=77+i*29,size=i?9:8,color=i?ink:'#839581';line(12,y+29,316,'#dce7d9');text(r[0],16,y+(29-size*1.5)/2,size,color);text(r[1],272,y+(29-size*1.5)/2,size,color,false,'right');if(!i)text(r[2],324,y+8.5,8,color,false,'right');else{const w=width(r[2],7)+10;box(324-w,y+7.25,w,14.5,4,'#dfebdc');text(r[2],329-w,y+9.25,7,'#507751');}c.restore();});
      c.save();c.globalAlpha*=ease(progress(time,start+750,300));text(schedule?'함께 준비할 일정':'예산 합계',16,205.25,9,'#6d8969');text(schedule?'3개 일정':'20,000,000원',324,203,12,'#507751',true,'right');c.restore();
      appear(4100,320,12,()=>{box(40,174,260,51,10,'#fff','#b5ceaf');icon('grid',52,186.5,26,accent);text('결혼준비_일정.xlsx',87,186,10,ink,true);text('다운로드 완료',87,201,8,'#6d8969');icon('check',274,192.5,14,accent);});
      toast('정리한 일정이 엑셀 파일로',4450);
    }
    function reminders() {
      const accent='#b77849',on=now>=2900;
      text('웨딩홀 잔금',12,43,12,'#6c4732',true);const tagW=width('10월 24일',8)+14;box(328-tagW,42,tagW,20,6,'#f0dfd0');text('10월 24일',335-tagW,46,8,'#ad7a52');
      text('결제 예정 금액',12,68,8,'#b39073');c.save();c.letterSpacing='-0.96px';text('6,500,000',12,80,24,'#6c4732',true);const amountW=width('6,500,000',24,true);c.letterSpacing='-0.4px';text(' 원',12+amountW,95,10,'#6c4732',true);c.restore();line(12,126,316,'#ead8c8');
      icon('bell',12,138.5,13,accent);text('결제일 알림',31,138.25,9);text(on?'결제일 7일 전':'꺼짐',36+width('결제일 알림',9),139.75,7,'#b39073');
      pulse(294,135,34,20,1100,accent,()=>{box(294,135,34,20,10,on?'#bb855b':'#cdbfb3');box(297+ease(progress(time,2900,300))*14,138,14,14,7,'#fff');});
      appear(3400,400,9,()=>{box(12,164,316,44,9,'#f3e3d4','#e3ccb7');box(21,173,26,26,8,'#bf8b62');icon('bell',26.5,178.5,15,'#fff');text('일주일 뒤, 웨딩홀 잔금 결제일이에요.',55,174.75,8);text('10월 24일 · 6,500,000원',55,186.75,7,'#ae8968');});
      popup(1300,2900,()=>{box(40,44,260,152,12,'#fff','#dbcbd5');text('언제 알려드릴까요?',52,56,10,ink,true);for(let i=0;i<2;i++){const y=83+i*35.5,picked=!i&&now>=2100;pulse(52,y,236,29.5,i?-1:2100,accent,()=>{box(52,y,236,29.5,7,picked?'#fbede1':'#fff',picked?'#bd8860':'#ecdfd4');text(i?'결제일 하루 전':'결제일 7일 전',61,y+8,9);if(picked)icon('check',268,y+9.25,11,accent);});}button('알림 설정',52,158,accent,2700,null,null,false,236);});
      toast('결제일 7일 전 알림을 설정했어요',3800);
    }
    function invitation() {
      const accent='#788357',name=typed('우진 & 채원',now,1600,120),x=15,y=68.5,w=174;
      text('우리의 청첩장',x,y,10,'#677b4b',true);text('대표 사진',x,y+23,7,'#a2aa8a');
      pulse(x,y+36.5,w,46,900,accent,()=>{box(x,y+36.5,w,46,7,'#ffffff99','#d7dccb');c.save();c.globalAlpha*=1-progress(time,1150,250);const tw=width('사진 넣기',8)+18;icon('photo',x+(w-tw)/2,y+52.5,14,'#9aa67e');text('사진 넣기',x+(w-tw)/2+18,y+53.5,8,'#a2aa8a');c.restore();photo(x+4,y+40.5,w-8,38,5,ease(progress(time,1150,400)));});
      field('청첩장 제목',name,'',x,y+89.5,w,'#d7dccb',now>=1600&&now<=2940&&Math.floor(now/330)%2===0);button('청첩장 만들기',x,y+139,accent,3100,null,'arrow',false,w);
      const px=205,py=53;
      c.save();c.globalAlpha*=ease(progress(time,3350,400));box(px-3,py-3,126,192,50,'#bac99e60');c.restore();
      box(px,py,120,186,[50,50,6,6],'#fffdf6','#cbd1b8');box(px+7,py+7,106,103,[42,42,3,3],'#f2f2e4','#d4d9c6');icon('photo',px+48,py+46.5,24,'#9aa67e');photo(px+7,py+7,106,103,[42,42,3,3],ease(progress(time,1150,400)));
      text('우리, 결혼합니다',px+60,py+118,6,'#a2aa8a',false,'center');text(name||' ',px+60,py+130,12,'#677b4b',true,'center',17);text('2027. 05. 22',px+60,py+147,6,'#8e9c71',false,'center');
      appear(3350,350,7,()=>{const bw=width('평생 소장',7)+31,bx=px+(120-bw)/2;box(bx,py+177.5,bw,18.5,9.25,'#eef4e6','#c2cea9');icon('sprout',bx+9,py+182.25,9,'#5d7744');text('평생 소장',bx+22,py+181.5,7,'#5d7744');});toast('우리의 청첩장이 완성됐어요',3650,9);
    }
    function render(milliseconds) {
      time=Math.max(0,Math.min(6600,milliseconds));now=Math.floor(time/50)*50;
      const scale=Math.max(.3,node.clientWidth/340)*(devicePixelRatio||1),dw=Math.round(340*scale),dh=Math.round(271*scale);
      if(canvas.width!==dw||canvas.height!==dh){canvas.width=dw;canvas.height=dh;}c.setTransform(dw/340,0,0,dh/271,0,0);c.clearRect(0,0,340,271);
      const kind=node.dataset.demo,index=['documents','excel','reminders','invitation'].indexOf(kind);
      c.save();c.beginPath();c.roundRect(0,0,340,271,14);c.clip();box(0,0,340,271,0,['#f7f1f8','#f1f7f1','#fcf3ec','#f4f4eb'][index]);box(0,0,340,31,0,'#ffffff88');line(0,30,340,'#54374612');
      if(logo.complete&&logo.naturalWidth){c.save();c.beginPath();c.roundRect(12,8.5,14,14,4);c.clip();c.drawImage(logo,12,8.5,14,14);c.restore();}text('웨딩플랜트',32,9.5,8);text(['플랜 추가','예산·일정 관리','결제 일정','청첩장 만들기'][index],328,10.25,7,faint,false,'right');
      [documents,excel,reminders,invitation][index]();c.restore();box(.5,.5,339,270,13.5,null,'#ffffff2e');node.dataset.demoTime=(time/1000).toFixed(2);
    }
    return {render};
  }
  const cardLogo=new Image();cardLogo.src='pass_card_logo.png';
  function card(node,milliseconds) {
    let canvas=node.querySelector('canvas');if(!canvas){canvas=document.createElement('canvas');canvas.style.cssText='width:100%;height:100%;display:block';node.append(canvas);}
    const scale=(node.clientWidth/190)*(devicePixelRatio||1),cw=Math.ceil(190*scale),ch=Math.ceil(280*scale);
    if(canvas.width!==cw||canvas.height!==ch){canvas.width=cw;canvas.height=ch;}
    const c=canvas.getContext('2d');c.setTransform(cw/190,0,0,ch/280,0,0);c.clearRect(0,0,190,280);
    function round(x,y,w,h,r,fill,stroke,lw=1){c.beginPath();c.roundRect(x,y,w,h,r);if(fill){c.fillStyle=fill;c.fill();}if(stroke){c.strokeStyle=stroke;c.lineWidth=lw;c.stroke();}}
    function text(v,x,y,size,color,bold=false,align='left',height=size*1.5,face='Kakao',tracking=0){c.font=`${bold?700:400} ${size}px ${face}`;c.letterSpacing=tracking+'px';c.textAlign=align;c.fillStyle=color;const m=c.measureText(v);c.fillText(v,x,y+(height-m.fontBoundingBoxAscent-m.fontBoundingBoxDescent)/2+m.fontBoundingBoxAscent);c.letterSpacing='0px';}
    c.save();c.beginPath();c.roundRect(0,0,190,280,16);c.clip();
    const grad=c.createLinearGradient(0,0,190,280);['#fff2f7','#efd6e6','#fce5e9','#d5aec3'].forEach((v,i)=>grad.addColorStop([0,.35,.64,1][i],v));round(0,0,190,280,16,grad,'#f4d7e8');
    for(let r=6;r<280;r+=7){c.beginPath();c.ellipse(95,95.2,r*.9,r,0,0,Math.PI*2);c.strokeStyle=`rgba(131,72,117,${.102*(1-r/280)})`;c.lineWidth=.6;c.stroke();}
    text('웨딩플랜트',18,22,8,'#493048',true);text('준비 패스',172,22,8,'#493048',true,'right');
    if(cardLogo.complete&&cardLogo.naturalWidth)c.drawImage(cardLogo,63,54.33,64,64);
    text('OUR NEXT CHAPTER',95,138.67,6,'#805a75',false,'center',9,'Kakao',1.32);
    text('준비 패스',95,151.67,33,'#412a3f',true,'center',40,'Round',-2.145);
    text('두 사람의 준비가',95,197.67,9,'#7b5871',false,'center',14);text('빛나는 하나의 패스.',95,211.67,9,'#7b5871',false,'center',14);
    text('weddingplant.app',18,249.75,7,'#493048');if(logo.complete&&logo.naturalWidth){c.save();c.beginPath();c.roundRect(158,248,14,14,4);c.clip();c.drawImage(logo,158,248,14,14);c.restore();}
    round(8,8,174,264,11,null,'#673d6080');round(11,11,168,258,8,null,'#ffffffcc');
    const sh=milliseconds/9000*Math.PI*2*20, lx=190*(.5+.42*Math.sin(sh*Math.PI/180)),ly=280*(.34+.06*Math.cos(sh*Math.PI/90));
    const foil=c.createLinearGradient(lx-190,ly-112,lx+190,ly+112);['#f39fd000','#f39fd033','#fff2d930','#d3b8ec33','#d3b8ec00'].forEach((v,i)=>foil.addColorStop(i/4,v));c.fillStyle=foil;c.fillRect(0,0,190,280);
    const glare=c.createRadialGradient(lx,ly,0,lx,ly,142.5);glare.addColorStop(0,'#ffffff8c');glare.addColorStop(.5,'#ffffff2e');glare.addColorStop(1,'#ffffff00');c.fillStyle=glare;c.beginPath();c.arc(lx,ly,142.5,0,Math.PI*2);c.fill();c.restore();
  }

  window.PassDemos={mount,card,total:6600};
})();
