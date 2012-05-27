#Micro Genetic Algorithm - slight variation on https://github.com/Sujimichi/micro_ga
class MGA
  require 'digest'

  attr_accessor :population, :generations, :mutation_rate, :cross_over_rate, :current_generation, :popsize, :scores
  def initialize args = {}
    @popsize = args[:popsize] || 30                   #Number of members (genomes) in the population
    @gene_length = args[:gene_length] || 10           #Number of bit (genes) in a genome
    @cross_over_rate = args[:cross_over_rate] || 0.7  #Prob. of selecting gene from fitter member during recombination
    @mutation_rate = args[:mutation_rate] || 0.1      #Per genome prob. of mutation (see readme)
    @generations = args[:generations] || 400          #Number of cycles to perform
    @population = Array.new(@popsize){ Array.new(@gene_length){ (1*rand - 0.5).round(2)} }   #Initialize population
    @fitness_function = args[:fitness] || Proc.new{|genome| genome.inject{|i,j| i+j} }  #init fitness function or use simple max ones
    @current_generation = 0
    @scores = {}
    @cache_fitness = args[:cache_fitness] || false
  end

  def evolve generations = @generations
    @popsize = @population.size #incase population was replaced with diff sized one.
    generations.times do |current_generation|      
      #Select two members at random and sort by fitness, select.first => fitter
      select = (0..@popsize-1).sort_by{rand}[0,2].sort_by {|ind| fitness(@population[ind]) }.reverse      
      #Replace % of weaker member's genes with fitter member's with a posibility of mutation.
      @population[select.last] = @population[select.last].zip(@population[select.first]).collect { |genes| pos_mutate( genes[ (rand<@cross_over_rate ? 1 : 0) ] ) }
      @current_generation += 1
    end
  end
  
  def pos_mutate n
    return n if rand >= @mutation_rate.to_f/@gene_length.to_f
    n + (rand - 0.5) #plus or minus small value. ||  (n-1).abs #for binary mutation; 1 -> 0, 0 -> 1        
  end
  def fitness genome
    return @fitness_function.call(genome, @current_generation) unless @cache_fitness  #return fitness as norm if caching is off
    @scores[genome] = @fitness_function.call(genome, @current_generation) unless @scores[genome] #update cache if value not present
    @scores[genome] #return cached value
  end
  
  def ordered_population
    population.sort_by{|member| fitness(member)}.reverse
  end

  def best
    ordered_population.first
  end
end

=begin
def cache_test

  f =  Proc.new{|genome| print'.';sleep(0.05); genome.inject{|i,j| i+j} } 
  pop = Array.new(30){ Array.new(10){ 0 } }   
  g1 = MGA.new(:cache => false, :generations => 5000, :fitness => f)
  g2 = MGA.new(:cache => true, :generations => 5000, :fitness => f)
  g1.population = pop
  g2.population = pop

  ave1 = g1.population.map{|g| g1.fitness g}.inject{|i,j| i+j} / g1.population.size
  ave2 = g2.population.map{|g| g1.fitness g}.inject{|i,j| i+j} / g2.population.size
  puts [ave1, ave2].inspect

  t1_1 = Time.now;g1.evolve; t1_2 = Time.now;
  t2_1 = Time.now;g2.evolve; t2_2 = Time.now;
  t1 = t1_2 - t1_1 
  t2 = t2_2 - t2_1

  ave1 = g1.population.map{|g| g1.fitness g}.inject{|i,j| i+j} / g1.population.size
  ave2 = g2.population.map{|g| g1.fitness g}.inject{|i,j| i+j} / g2.population.size
  puts [ave1, ave2].inspect
  puts [t1, t2].inspect


end
=end
