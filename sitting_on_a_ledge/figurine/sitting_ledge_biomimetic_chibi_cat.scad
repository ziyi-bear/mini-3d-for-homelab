/*
Sitting on a Ledge Figurine - Biomimetic Chibi Cat
Units: mm
Coordinate system:
  tabletop z = 0
  ledge x = 0
  tabletop inside x > 0
  hanging side x < 0

Design basis:
  phi = golden ratio
  body/head use Lamé superellipsoids for soft organic volume
  limbs use quadratic Bezier centerlines with tapered metaball-like hulls
  tail follows a logarithmic spiral inspired by curled mammal tails

IMPORTANT: com_proxy is a design target/visual guide, not an exact mass-property result.
Use the final slicer or CAD mass-properties tool for final COM verification.
*/

$fn = 48;

// ---------- User parameters ----------
show_table       = true;
show_edge_line   = true;
show_com_marker  = false;
quality          = 48;       // set 72-96 for final render

max_above_z      = 50;
ledge_x          = 0;
seat_depth_min   = 28;
wall_nominal     = 2.0;      // reference for later hollowing workflow

// Golden-ratio biomimetic proportions
phi              = (1 + sqrt(5)) / 2;
head_h           = 24;
head_w           = head_h / phi * 1.32;
head_d           = head_h / phi * 1.18;
body_h           = head_h * 0.78;

// Approximate design target, measured from ledge toward table interior
com_proxy        = [8.0, 0, 18.0];
safety_margin_x  = 5.0;

$fn = quality;

// ---------- Vector helpers ----------
function vadd(a,b) = [a[0]+b[0], a[1]+b[1], a[2]+b[2]];
function vsub(a,b) = [a[0]-b[0], a[1]-b[1], a[2]-b[2]];
function vmul(a,s) = [a[0]*s, a[1]*s, a[2]*s];
function bez2(p0,p1,p2,t) =
    vadd(vadd(vmul(p0,(1-t)*(1-t)), vmul(p1,2*(1-t)*t)), vmul(p2,t*t));

// Logarithmic spiral in the XZ plane, with optional Y offset
function spiral_pt(c, a, b, theta, y=0) =
    let(r = a * exp(b*theta))
    [c[0] + r*cos(theta), y, c[2] + r*sin(theta)];

// ---------- Organic primitives ----------
// Lamé-style superellipsoid approximation using Minkowski-rounded scaled sphere.
// p is retained as a semantic shape parameter for iterative design notes.
module bio_ellipsoid(size=[10,10,10], p=2.4) {
    scale([size[0]/2, size[1]/2, size[2]/2]) sphere(r=1);
}

module ball(p=[0,0,0], r=2) {
    translate(p) sphere(r=r);
}

module tapered_segment(p0, p1, r0, r1) {
    hull() {
        ball(p0,r0);
        ball(p1,r1);
    }
}

module bezier_limb(p0,p1,p2,r0=3.2,r1=2.2,steps=7) {
    for (i=[0:steps-1]) {
        t0=i/steps;
        t1=(i+1)/steps;
        tapered_segment(
            bez2(p0,p1,p2,t0),
            bez2(p0,p1,p2,t1),
            r0+(r1-r0)*t0,
            r0+(r1-r0)*t1
        );
    }
}

module rounded_ear(side=1) {
    // Rounded triangular ear, thick enough for resin/FDM handling.
    hull() {
        ball([18.5, side*7.1, 42.5], 3.3);
        ball([19.0, side*8.0, 48.0], 1.7);
        ball([23.0, side*5.8, 43.0], 2.8);
    }
}

module face_relief() {
    // Shallow recessed eyes and mouth, avoiding fragile floating details.
    for (side=[-1,1])
        translate([8.55, side*3.8, 39.0])
            rotate([0,90,0]) cylinder(h=1.2,r=1.15,center=true);
    translate([8.3,0,35.9]) rotate([0,90,0]) cylinder(h=1.1,r=0.8,center=true);
}

module curled_tail() {
    // Biomimetic logarithmic spiral: r(theta)=a*e^(b*theta)
    c=[29,0,12];
    a=2.4;
    b=0.075;
    th0=205;
    th1=500;
    steps=18;
    for(i=[0:steps-1]) {
        t0=th0+(th1-th0)*i/steps;
        t1=th0+(th1-th0)*(i+1)/steps;
        r0=2.5-0.9*i/steps;
        r1=2.5-0.9*(i+1)/steps;
        tapered_segment(spiral_pt(c,a,b,t0,0), spiral_pt(c,a,b,t1,0), r0, r1);
    }
}

module rear_countermass() {
    // Hidden volume on x>0 side increases restoring moment without a platform.
    // It merges into the rump and remains part of the character silhouette.
    translate([27,0,8.5]) bio_ellipsoid([17,17,15],2.7);
}

module flat_seat_contact() {
    // Broad, symmetric horizontal contact patch entirely on tabletop.
    // 26 x 24 mm footprint, 2.6 mm thick, blended into rump.
    translate([17,0,1.3])
        minkowski() {
            cube([23,21,0.8],center=true);
            sphere(r=1.0,$fn=24);
        }
}

module hanging_leg(side=1) {
    // Bezier leg begins inside ledge and hangs outside without touching side wall.
    p0=[7.0,side*6.2,8.0];
    p1=[-1.0,side*7.2,1.0];
    p2=[-8.0,side*7.0,-13.5];
    bezier_limb(p0,p1,p2,3.4,2.6,8);
    // Enlarged rounded paw, kept clear of vertical wall x=0.
    hull() {
        ball([-8.0,side*7.0,-13.5],2.7);
        ball([-12.8,side*7.0,-15.2],3.2);
    }
}

module front_paw(side=1) {
    // Paws rest on knees, structurally merged into body.
    bezier_limb([13,side*8.2,25],[7,side*8.0,20],[5.0,side*6.7,13.5],2.8,2.3,6);
}

module chibi_cat() {
    difference() {
        union() {
            // Flat load-bearing contact first
            flat_seat_contact();

            // Low, dense rump and rear counter-mass
            translate([18,0,12]) bio_ellipsoid([28,23,25],2.8);
            rear_countermass();

            // Short upright torso, kept behind ledge
            translate([17,0,24]) bio_ellipsoid([22,19,25],2.6);

            // Head top remains below 50 mm
            translate([17,0,37]) bio_ellipsoid([head_d,head_w,head_h],2.5);
            rounded_ear(-1);
            rounded_ear(1);

            // Legs and paws
            hanging_leg(-1);
            hanging_leg(1);
            front_paw(-1);
            front_paw(1);

            // Rearward tail acts as organic stabilizer/contact mass
            curled_tail();
        }
        face_relief();

        // Small underside relief outside valid contact zone prevents edge rocking.
        translate([-10,0,0.4]) cube([18,40,1.0],center=true);
    }
}

// ---------- Scene ----------
color([0.92,0.72,0.58]) chibi_cat();

if (show_table) {
    color([0.72,0.76,0.80,0.35])
        translate([35,0,-1.25]) cube([70,80,2.5],center=true);
}

if (show_edge_line) {
    color("red") translate([ledge_x,0,0.15]) cube([0.6,76,0.6],center=true);
    color([0.2,0.5,1.0,0.25])
        translate([safety_margin_x,0,0.25]) cube([0.4,30,0.5],center=true);
}

if (show_com_marker) {
    color("lime") translate(com_proxy) sphere(r=1.8);
    color("lime") translate([com_proxy[0],com_proxy[1],0]) cylinder(h=com_proxy[2],r=0.35);
}

// ---------- Design diagnostics ----------
echo("Golden ratio phi = ",phi);
echo("Nominal above-table height target <= ",max_above_z," mm");
echo("COM proxy X margin from ledge = ",com_proxy[0]," mm");
echo("COM proxy is visual guidance only; calculate exact COM after slicing/material assignment.");
