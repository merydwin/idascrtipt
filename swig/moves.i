
// Ignore kernel only symbols
%ignore init_marks;
%ignore term_marks;
%ignore change_jumps_stack_format;
%ignore move_marks;
%ignore curloc_after_segments_moved;
%ignore curloc::rebase_stack;
%ignore loc_gtag;
%ignore DEFINE_CURLOC_HELPERS;
%ignore DEFINE_LOCATION_HELPERS;

%include "moves.hpp"