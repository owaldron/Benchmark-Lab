use std::env;
use std::fs::File;
use std::io::Write;
use std::time::Instant;

// This is a simple benchmark experiment that simulates some work and measures runtime and accuracy.
// Replace this with your actual experiment logic and metrics as needed.

fn main() {
    let results_path = env::args().nth(1).unwrap_or_else(|| "results.json".to_string());

    println!("=== Benchmark Experiment ===");

    // --- Dummy experiment with real timing ---
    let start = Instant::now();

    let mut sum = 0.0_f64;
    for i in 0..1_000_000 {
        sum += (i as f64).sqrt();
    }

    let runtime = start.elapsed().as_secs_f64();
    let accuracy = 0.95; // placeholder metric

    println!("Experiment complete.");
    println!("  Runtime:  {:.4}s", runtime);
    println!("  Accuracy: {:.2}", accuracy);

    // --- Write results to JSON ---
    let json_data = format!(
        r#"{{
    "runtime": {:.6},
    "accuracy": {:.2},
    "checksum": {:.4}
}}"#,
        runtime, accuracy, sum
    );

    let mut file = File::create(&results_path).expect("Unable to create results file");
    file.write_all(json_data.as_bytes()).expect("Unable to write results");
    println!("Results written to {}", results_path);
}
