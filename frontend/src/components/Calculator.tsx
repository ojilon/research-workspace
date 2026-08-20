import { useState } from "react";
import { Add } from "../../wailsjs/go/main/App";

export default function Calculator() {
    //specify the types
    const [num1, setNum1] = useState(0);
    const [num2, setNum2] = useState(0);
    const [calcResult, setCalcResult] = useState<string>('Result: 0');

    function handleCalculation() {
        //wails maps Go's int64 to JavaScript numbers
        Add(num1, num2).then((response: string) => {
            setCalcResult(response);
        }).catch((err) => {
            setCalcResult(`Error: ${err}`);
        });
    }

    return (
        <div >
            <h2 >Go Math Bridge</h2>
            <div>
                <input
                    type="text"
                    value={num1}
                    onChange={(e) => setNum1(Number(e.target.value))}/>
                <span>+</span>
                <input
                    type="number"
                    value={num2}
                    onChange={(e) => setNum2(Number(e.target.value))}
                />
            </div>

            <button onClick={handleCalculation}>
                Compute in Go
            </button>
            <div>{calcResult}</div>
        </div>
        );
}