#ifdef GL_ES
precision highp float;
#endif

uniform vec2 u_resolution;
uniform vec2 u_mouse;
uniform float u_time;

const int MAX_MARCHING_STEPS=300;
const float MIN_DIST=.001;
const float MAX_DIST=20.;
const float PRECISION=.0008;

// Rotation matrix around the X axis.
mat3 rotateX(float theta){
  float c=cos(theta);
  float s=sin(theta);
  return mat3(
    vec3(1,0,0),
    vec3(0,c,-s),
    vec3(0,s,c)
  );
}

// Rotation matrix around the Y axis.
mat3 rotateY(float theta){
  float c=cos(theta);
  float s=sin(theta);
  return mat3(
    vec3(c,0,s),
    vec3(0,1,0),
    vec3(-s,0,c)
  );
}

// Rotation matrix around the Z axis.
mat3 rotateZ(float theta){
  float c=cos(theta);
  float s=sin(theta);
  return mat3(
    vec3(c,-s,0),
    vec3(s,c,0),
    vec3(0,0,1)
  );
}

// Identity matrix.
mat3 identity(){
  return mat3(
    vec3(1,0,0),
    vec3(0,1,0),
    vec3(0,0,1)
  );
}

float sdSphere(vec3 p,float r)
{
  vec3 offset=vec3(0,0,-2);
  return length(p-offset)-r;
}
float mandelBulb(vec3 p,mat3 transform)
{
  vec3 w=p*transform;
  float m=dot(w,w);
  
  vec4 trap=vec4(abs(w),m);
  float dz=1.;
  float power=8.3;
  
  for(int i=0;i<3;i++)
  {
    // dz = 8*z^7*dz
    dz=8.*pow(m,3.5)*dz;
    
    // z = z^8+z
    float r=length(w);
    // rotateX(w);
    float b=power*acos(w.y/r)+u_time/2.;
    float a=power*atan(w.x,w.z);
    w=p+pow(r,power)*vec3(sin(b)*sin(a),cos(b),sin(b)*cos(a));
    //w *= abs(sin(b)*cos(a)*log(2. * abs(cos(a))))+.8;
    w *= abs(tan(a) * sin(a) * abs(sin(a))) * .5 * abs(sin(a)) * sin(cos(b)) * abs(cos(a)) + .9;
    //w = mod(u_time,w.x);
    trap=min(trap,vec4(abs(w),m));
    
    m=dot(w,w) ;
    if(m>256.)
    break;
  }
  // distance estimation (through the Hubbard-Douady potential)
  return.035*log2(m)*(sqrt(m)/dz) * 2.;
}
vec2 rayMarch(vec3 ro,vec3 rd){
  float depth=.2;
  int iteration = 0;
  
  for(int i=0;i<MAX_MARCHING_STEPS;i++){
    iteration = i;
    vec3 p=ro+depth*rd;
    //float d=sdSphere(p,1.);
    float d=mandelBulb(p,rotateX(u_mouse.y/500.)*rotateY(-u_mouse.x/500.)*rotateZ(u_time/5.));
    depth+=d;
    if(d<PRECISION||depth>MAX_DIST)break;
  }
  
  return vec2(depth,iteration);
}

vec3 calcNormal(vec3 p){
  vec2 e=vec2(2.,2.)*.000001;// epsilon
  float r=1.;// radius of sphere
  return normalize(
    e.xyy*mandelBulb(p+e.xyy,identity())+
    e.yyx*mandelBulb(p+e.yyx,identity())+
    e.yxy*mandelBulb(p+e.yxy,identity())+
    e.xxx*mandelBulb(p+e.xxx,identity()));
  }
  
  void main()
  {
    vec2 uv=gl_FragCoord.xy/u_resolution;
    uv-=.5;
    uv.x*=u_resolution.x/u_resolution.y;
    
    vec3 col=vec3(0.1843, 0.4, 0.4353);
    vec3 ro=vec3(0,0,3);// ray origin that represents camera position
    vec3 rd=normalize(vec3(uv,-1));// ray direction
    
    vec2 rmComponents = rayMarch(ro,rd);
    float d = rmComponents.x;// distance to sphere
    float ite = rmComponents.y;

    float multiplier = pow(ite/float(MAX_MARCHING_STEPS),.9) * 1.5;
    
    if(d>MAX_DIST){
      col=vec3(0.8745, 0.5098, 0.9686) * multiplier * 1.5;// ray didn't hit anything
    }
    else{
      vec3 p=ro+rd*d;// point on sphere we discovered from ray marching
      vec3 normal=calcNormal(p - d);
      vec3 lightPosition=vec3(1.,.5,2.2);
      vec3 lightDirection=normalize(lightPosition-p);
      
      // Calculate diffuse reflection by taking the dot product of
      // the normal and the light direction.
      float dif=clamp(dot(normal,lightDirection),0.,1.);
      //shadow
      vec3 newRayOrigin=p;
      float shadowRayLength=rayMarch(newRayOrigin,lightDirection).x;// cast shadow ray to the light source
      if(shadowRayLength<length(lightPosition-newRayOrigin))dif*=.8;// if the shadow ray hits the sphere, set the diffuse reflection to zero, simulating a shadow
      col=vec3(dif)*vec3(0.4275, 0.4157, 0.9765)*pow(.2-d,2.)/1.5 *  multiplier * 1.5;
    }
    
    // Output to screen
    gl_FragColor=vec4(col,1.);
  }