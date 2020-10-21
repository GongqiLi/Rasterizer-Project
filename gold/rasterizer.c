#include "rasterizer.h"
#include <stdlib.h>

#ifdef __cplusplus
#include <vector>
#endif

/* Utility Functions */

/*
 *   Function: min
 *  Function Description: Returns the minimum value of two integers and b.
*/
int min(int a, int b) {
  // START CODE HERE

  if (a < b)
    return a;
  return b;
  // END CODE HERE
}

/*
 *   Function: max
 *   Function Description: Returns the maximum value of two integers and b.
*/
int max(int a, int b) {
  // START CODE HERE
  if (a > b)
    return a;
  return b;
  // END CODE HERE
}

/*
/   Function: floor_ss
/   Function Description: Returns a fixed point value rounded down to the
subsample grid.
*/
int floor_ss(int val, int r_shift, int ss_w_lg2) {
  // START CODE HERE
  val = val >> r_shift;
  return val;
  // END CODE HERE
}

/*
 *  Function: rastBBox_bbox_fix
 *  Function Description: Determine a bounding box for the triangle.
 *  Note that this is a fixed point function.
*/
BoundingBox get_bounding_box(Triangle triangle, Screen screen, Config config) {
  BoundingBox bbox;
  int minx, miny, maxx, maxy;
  // START CODE HERE
  minx = min(triangle.v[0].x, triangle.v[1].x);
  minx = min(triangle.v[2].x, minx);
  miny = min(triangle.v[0].y, triangle.v[1].y);
  miny = min(triangle.v[2].y, miny);
  maxx = max(triangle.v[0].x, triangle.v[1].x);
  maxx = max(triangle.v[2].x, maxx);
  maxy = max(triangle.v[0].y, triangle.v[1].y);
  maxy = max(triangle.v[2].y, maxy);
  // Calculate clamped bounding box
  // min  x rounded down to subsample grid
  bbox.lower_left.x = floor_ss(minx, config.r_shift, config.ss_w_lg2);
  // Max x rounded down to subsample grid
  bbox.upper_right.x = floor_ss(maxx, config.r_shift, config.ss_w_lg2);
  // min y rounded down to subsample grid
  bbox.lower_left.y = floor_ss(miny, config.r_shift, config.ss_w_lg2);
  // Max y rounded down to subsample grid
  bbox.upper_right.y = floor_ss(maxy, config.r_shift, config.ss_w_lg2);
  // Clip bounding box to visible screen space
  bbox.upper_right.x =
      bbox.upper_right.x > screen.width ? screen.width : bbox.upper_right.x;
  bbox.upper_right.y =
      bbox.upper_right.y > screen.height ? screen.height : bbox.upper_right.y;
  bbox.lower_left.x = bbox.lower_left.x < 0 ? 0 : bbox.lower_left.x;
  bbox.lower_left.y = bbox.lower_left.y < 0 ? 0 : bbox.lower_left.y;
  bbox.valid = true;

  // END CODE HERE
  return bbox;
}

/*
 *  Function: sample_test
 *  Function Description: Checks if sample lies inside triangle
 *
 *
 */
bool sample_test(Triangle triangle, Sample sample) {
  bool isHit, b[3];
  int dist[3];
  Vertex2D w[3];
  // START CODE HERE
  // Shift vertices such that sample is origin
  for (int i = 0; i < 3; i++) {
    w[i].x = triangle.v[i].x - sample.width;
    w[i].y = triangle.v[i].y - sample.height;
  }
  // Distance of  origin shifted edge
  dist[0] = w[0].x * w[1].y - -w[1].x * w[0].y; // 0 -1 edge
  dist[1] = w[1].x * w[2].y - w[2].x * w[1].y;  // 1 -2 edge
  dist[2] = w[2].x * w[0].y - w[0].x * w[2].y;  // 2 -0 edge
  // Test if origin is on right side of shifted edge
  for (int i = 0; i < 3; i++) {
    b[i] = dist[i] <= 0.0;
  }
  // Triangle min terms with no culling
  // triRes = ( b0 && b1 && b2 ) || (! b0 && ! b1 && ! b2 ) ;
  // Triangle min terms with backface culling
  isHit = b[0] && b[1] && b[2];

  // END CODE HERE
  return isHit;
}

int rasterize_triangle(Triangle triangle, ZBuff *z, Screen screen,
                       Config config) {
  int hit_count = 0;

  // Calculate BBox
  BoundingBox bbox = get_bounding_box(triangle, screen, config);

  // Iterate over samples and test if in triangle
  Sample sample;
  for (sample.x = bbox.lower_left.x; sample.x <= bbox.upper_right.x;
       sample.x += config.ss_i) {
    for (sample.y = bbox.lower_left.y; sample.y <= bbox.upper_right.y;
         sample.y += config.ss_i) {

      Sample jitter = jitter_sample(sample, config.ss_w_lg2);
      jitter.x = jitter.x << 2;
      jitter.y = jitter.y << 2;

      Sample jittered_sample;
      jittered_sample.x = sample.x + jitter.x;
      jittered_sample.y = sample.y + jitter.y;

      bool hit = sample_test(triangle, jittered_sample);

      if (hit) {
        hit_count++;
        if (z != NULL) {
          Sample hit_location;
          hit_location.x = sample.x >> config.r_shift;
          hit_location.y = sample.y >> config.r_shift;

          Sample subsample;
          subsample.x =
              (sample.x - (hit_location.x << config.r_shift)) / config.ss_i;
          subsample.y =
              (sample.y - (hit_location.y << config.r_shift)) / config.ss_i;

          Fragment f;
          f.z = triangle.v[0].z;
          f.R = triangle.v[0].R;
          f.G = triangle.v[0].G;
          f.B = triangle.v[0].B;

          process_fragment(z, hit_location, subsample, f);
        }
      }
    }
  }

  return hit_count;
}

void hash_40to8(uchar *arr40, ushort *val, int shift) {
  uchar arr32[4];
  uchar arr16[2];
  uchar arr8;

  ushort mask = 0x00ff;
  mask = mask >> shift;

  arr32[0] = arr40[0] ^ arr40[1];
  arr32[1] = arr40[1] ^ arr40[2];
  arr32[2] = arr40[2] ^ arr40[3];
  arr32[3] = arr40[3] ^ arr40[4];

  arr16[0] = arr32[0] ^ arr32[2];
  arr16[1] = arr32[1] ^ arr32[3];

  arr8 = arr16[0] ^ arr16[1];

  mask = arr8 & mask;
  val[0] = mask;
}

Sample jitter_sample(const Sample sample, const int ss_w_lg2) {
  long x = sample.x >> 4;
  long y = sample.y >> 4;
  uchar arr40_1[5];
  uchar arr40_2[5];

  long *arr40_1_ptr = (long *)arr40_1;
  long *arr40_2_ptr = (long *)arr40_2;

  ushort val_x[1];
  ushort val_y[1];

  *arr40_1_ptr = (y << 20) | x;
  *arr40_2_ptr = (x << 20) | y;

  hash_40to8(arr40_1, val_x, ss_w_lg2);
  hash_40to8(arr40_2, val_y, ss_w_lg2);

  Sample jitter;
  jitter.x = val_x[0];
  jitter.y = val_y[0];

  return jitter;
}
