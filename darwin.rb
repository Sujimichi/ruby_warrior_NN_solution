#Micro Genetic Algorithm by Jeremy Comer
class MGA
  attr_accessor :population, :generations, :mutation_rate, :cross_over_rate, :current_generation, :popsize

  def initialize args = {}
    @popsize = args[:popsize] || 30                   #Number of members (genomes) in the population
    @gene_length = args[:gene_length] || 10           #Number of bit (genes) in a genome
    @cross_over_rate = args[:cross_over_rate] || 0.7  #Prob. of selecting gene from fitter member during recombination
    @mutation_rate = args[:mutation_rate] || 0.1      #Per genome prob. of mutation (see readme)
    @generations = args[:generations] || 400          #Number of cycles to perform
    @population = Array.new(@popsize){ Array.new(@gene_length){ (1*rand - 0.5).round(2)} }   #Initialize population
    #@population = Array.new(@popsize){ Array.new(@gene_length){ (1*rand).round} }   #Initialize population
    @fitness_function = args[:fitness]
    @current_generation = 0
  end

  def evolve
    @popsize = @population.size #incase population was replaced with diff sized one.
    @generations.times do |current_generation|
      @current_generation += 1
      select = (0..@popsize-1).sort_by{rand}[0,2].sort_by {|ind| fitness(@population[ind]) }.reverse
      #Select two members at random and sort by fitness, select.first => fitter
      @population[select.last] = @population[select.last].zip(@population[select.first]).collect { |genes|
        pos_mutate( genes[ (rand<@cross_over_rate ? 1 : 0) ] )
      } #Replace % of weaker member's genes with fitter member's with a posibility of mutation.
    end
  end

  def pos_mutate n
    return n if rand >= @mutation_rate.to_f/@gene_length.to_f
    n + (rand - 0.5) #plus or minus small value.
    #n + rand*0.1 - 0.05

    #(n-1).abs #binary mutation; 1 -> 0, 0 -> 1
  end

  def fitness genome
    @fitness_function ||= Proc.new{|genome| genome.inject{|i,j| i+j} }
    @fitness_function.call(genome, @current_generation)
  end

  def ordered_population
    population.sort_by{|member| fitness(member)}.reverse
  end

  def best
    ordered_population.first
  end
end
