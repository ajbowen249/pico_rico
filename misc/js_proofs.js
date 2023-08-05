/**
 * This is the proof that the original segment-segment intersection algorithm did work. Running this in a js console gives the correct intersection when the
 * same code in Lua in Pico-8 failed. Pico-8 has fixed-point, 32-bit math, so that is the likely cuprit.
 */

function min(v1, v2) {
  if (v1 < v2) {
    return v1
  } else {
    return v2;
  }
}

function max(v1, v2) {
  if (v1 > v2) {
    return v1
  } else {
    return v2;
  }
}

function new_window(min_x, min_y, max_x, max_y) {
  return {
   min_x: min_x,
   min_y: min_y,
   max_x: max_x,
   max_y: max_y,
  }
}

function is_in_window(self, window, exclude) {
  return ((exclude != null && exclude.min_x == true) || self.x >= window.min_x) &&
          ((exclude != null && exclude.max_x == true) || self.x <= window.max_x) &&
          ((exclude != null && exclude.min_y == true) || self.y >= window.min_y) &&
          ((exclude != null && exclude.max_y == true) || self.y <= window.max_y)
}

function new_point(x, y) {
  return {
    x,
    y,
  }
}

function segment_segment_intersect(p1, p2, p3, p4) {
  const tn = ((p1.x - p3.x) * (p3.y - p4.y)) - ((p1.y - p3.y) * (p3.x - p4.x))
  const td = ((p1.x - p2.x) * (p3.y - p4.y)) - ((p1.y - p2.y) * (p3.x - p4.x))
  const t = tn / td

  const un = ((p1.x - p3.x) * (p1.y - p2.y)) - ((p1.y - p3.y) * (p1.x - p2.x))
  const ud = ((p1.x - p2.x) * (p3.y - p4.y)) - ((p1.y - p2.y) * (p3.x - p4.x))
  const u = un / ud

  const segment_1_window = new_window(
    min(p1.x, p2.x),
    min(p1.y, p2.y),
    max(p1.x, p2.x),
    max(p1.y, p2.y)
  )

  const segment_2_window = new_window(
    min(p3.x, p4.x),
    min(p3.y, p4.y),
    max(p3.x, p4.x),
    max(p3.y, p4.y)
  )

  let p = null

  if (t >= 0 && t <= 1) {
    p = new_point(
      p1.x + (t * (p2.x - p1.x)),
      p1.y + (t * (p2.y - p1.y))
    )
  } else if ( u >= 0 && u <= 1) {
    p = new_point(
      p3.x + (u * (p4.x - p3.x)),
      p3.y + (u * (p4.y - p3.y))
    )
  }

  if (p != null && is_in_window(p, segment_1_window) && is_in_window(p, segment_2_window)) {
    return { p };
  } else {
    return {};
  }
}

function line_line_intersect(p1, p2, p3, p4) {
  const denominator = ((p1.x - p2.x) * (p3.y - p4.y)) - ((p1.y - p2.y) * (p3.x - p4.x));
  if ( denominator == 0) {
    return {};
  }

  const common_1 = (p1.x * p2.y) - (p1.y * p2.x);
  const common_2 = (p3.x * p4.y) - (p3.y * p4.x);

  return [
    new_point(
      (common_1 * (p3.x - p4.x) - (p1.x - p2.x) * common_2) / denominator,
      (common_1 * (p3.y - p4.y) - (p1.y - p2.y) * common_2) / denominator
    ),
  ];
}

function t1() {
  const tp1 = new_point(2.5677, 72.9829);
  const tp2 = new_point(52.876, 72.8492);
  const tp3 = new_point(40, 69.9997);
  const tp4 = new_point(40, 73.9997);

  const res = segment_segment_intersect(tp1, tp2, tp3, tp4);
  console.log(res);
}

function t2() {
  const tp1 = new_point(912.3442, 500.6497);
  const tp2 = new_point(915.0197, 503.6231);

  const tp3 = new_point(896.7417, 492.9106);
  const tp4 = new_point(920.830, 505.3188);

  const res = segment_segment_intersect(tp1, tp2, tp3, tp4);
  console.log(res);
}

function t3() {
  const tp1 = new_point(912.3442, 500.6497);
  const tp2 = new_point(915.0197, 503.6231);

  const tp3 = new_point(896.7417, 492.9106);
  const tp4 = new_point(920.830, 505.3188);

  const res = line_line_intersect(tp1, tp2, tp3, tp4);
  console.log(res);
}


t3();
