include std/get.e
include std/unittest.e

constant ABC=20

enum A,B,C
enum D=-2,E,F,G
enum H,I,J=20,K,L=30,M
enum O=50,P,Q=0,R,S=50,T
enum U=#50,V,W
enum X=10,Y=X,Z=X,ZZ=ABC

test_equal("enum #1", {1,2,3}, {A,B,C})
test_equal("enum #2", {-2,-1,0,1}, {D,E,F,G})
test_equal("enum #3", {1,2,20,21,30,31}, {H,I,J,K,L,M})
test_equal("enum #4", {50,51,0,1,50,51}, {O,P,Q,R,S,T})
test_equal("enum #5", {#50,#51,#52}, {U,V,W})
test_equal("enum #6", {10,10,10,20}, {X,Y,Z,ZZ})

test_report()

