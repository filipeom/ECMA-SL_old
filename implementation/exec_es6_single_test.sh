node ../JS2ECMA-SL/src/index.js -c -i $1 -o ast.cesl
./main.native -mode c -i ES6_interpreter/main.esl -o core.cesl 
echo "; " >> core.cesl 
cat ast.cesl >> core.cesl
./main.native -mode ci -i core.cesl > result2.txt
rm core.cesl ast.cesl
