source("basic_functions.R")
#install.packages("doParallel")
library(doParallel)



Power_parallel <- function(data, sample_size,
                           noise_mean, noise_sd, noise_fwhm,
                           signal,
                           method, n_iterations,
                           Continuum_size = 101,
                           domain_points = NULL,
                           Write_file = FALSE,
                           file_name = "Power_Results.xlsx"){
  
  # Capture input argument names and values
  input_info <- data.frame(
    data = ifelse(is.null(data),"NULL",deparse(substitute(data))),         # Store the name of 'data' as a string
    sample_size = sample_size,                # Numeric value
    noise_mean = noise_mean,                  # Numeric value
    noise_sd = noise_sd,                      # Numeric value
    noise_fwhm = noise_fwhm,                  # Numeric value
    signal = ifelse(is.null(signal),"NULL",signal),        # Numeric value
    method = paste(method, collapse = ", "),  # Store 'method' as a string of methods
    n_iterations = n_iterations               # Numeric value
  )
  
  # Initialize the method list
  method_list <- Initialize_method_list(Methods = method,
                                        Conti_size = ifelse(is.null(domain_points),Continuum_size,domain_points),
                                        Iter_number = n_iterations)
  
  # parallelize the power calculation
  number_cores=detectCores() #number of cores
  registerDoParallel(number_cores) #register the number of cores
  
  # The .combine function in foreach always takes two inputs at a time:
  # First: The cumulative result of previous iterations (starting with an initial value, if provided)
  # Second: The result of the current iteration of the loop
  loop <- foreach (k = (1:n_iterations),.combine = parallel_combine_function,
                   .init = method_list) %dopar% {
                     
                     # Generate the data
                     generated_data <- Power_data_generator(Sample_size = sample_size,
                                                            Data = data,
                                                            Signal = signal,
                                                            Conti_size = Continuum_size,
                                                            Noise_mu = noise_mean,
                                                            Noise_sig = noise_sd,
                                                            Noise_fwhm = noise_fwhm,
                                                            n_evaluation_points = domain_points)
                     
                     # Calculate the pvalues for each method
                     method_list <- Pvalue_calculator(method_list, generated_data$data1,
                                                      generated_data$data2)
                     
                   }
  
  
  # Stop the parallel backend
  stopImplicitCluster()
  
  # Calculate the power based on the result
  power_results <- Power_calculator(loop , n_iterations, Alpha = 0.05)
  
  # Add power results to input_info dataframe for each method
  for (method_name in names(power_results)) {
    # Add a new column with the power result for each method
    input_info[[method_name]] <- power_results[[method_name]]
  }
  
  if (Write_file == TRUE) {
    
    # Call the external function to write results to Excel
    write_results_to_excel(loop, power_results, input_info, file_name)
    
    
  }
  
  
  
  return(list(Pvalues_methods = loop, Power_results = power_results,
              Input_Summary = input_info, File = file_name))
  
}



