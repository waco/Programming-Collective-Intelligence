require 'yaml'

class Recoomedations
  def self.get_recomended_items(prefs, item_match, user)
    user_ratings = prefs[user]
    scores={}
    total_sim={}

    # このユーザに評価されたアイテムをループする
    user_ratings.each do |item, rating|
      # このアイテムに似ているアイテムたちをループする
      item_match[item].each do |similarity, item2|
        # このアイテムに対してユーザがすでに評価を行っていれば無視する
        next if user_ratings[item2]

        # 評点と類似度を掛け合わせたものの合計で重みづけをする
        scores[item2] ||= 0
        scores[item2] += similarity*rating

        # すべての類似度の合計
        total_sim[item2] ||= 0
        total_sim[item2] += similarity
      end
    end
    # 正規化のため、それぞれの重みづけしたスコアを類似度の合計で割る
    rankings = scores.map { |item, score| [score/total_sim[item], item] }

    rankings.sort!
    rankings.reverse!
    rankings
  end

  # アイテムをキーとして持ち、それぞれのアイテムに似ている
  # アイテムのリストを値として持つディクショナリを作る
  def self.calcurate_similar_items(prefs, params={})
    n = params[:n] ? params[:n] : 5 # 結果の数
    similarity = params[:similarity] ? params[:similarity] : :sim_distance
    result={}
    
    item_prefs = transform_prefs(prefs)
    c=0
    item_prefs.each do |item, person|
      # 巨大なデータセット用にステータスを表示
      c+=1
      puts "%d/%d" % [c,item_prefs.size] if c%100==0
      # このアイテムにもっとも似ているアイテムたちを探す
      scores = top_matches(item_prefs,item,:n=>n,:similarity=>similarity)
      result[item]=scores
    end

    result
  end

  # person以外の全ユーザの評点の重み付き平均を使い、personへの推薦を算出する
  def self.get_recommendations(prefs, person, params={})
    totals = {}
    simSums = {}
    similarity = params[:similarity] ? params[:similarity] : :sim_pearson
    prefs.each do |other, items|
      # 自分自身とは比較しない
      next if other==person
      sim = self.send(similarity, prefs, person, other)

      # 0以下のスコアは無視する
      next if sim <= 0

      items.each do |item, value|
        # まだ見ていない映画の得点のみ算出
        if prefs[person][item].nil? || prefs[person][item] == 0 then
          # 類似度 * スコア
          totals[item] ||= 0
          totals[item] += value * sim
          # 類似度を合計
          simSums[item] ||= 0
          simSums[item] += sim
        end
      end
    end
    # 正規化したリストを作る
    rankings=totals.map do |item, total|
      [total/simSums[item],item]
    end
    # ソート済みのリストを返す
    rankings.sort!
    rankings.reverse!

    rankings
  end

  # itemとpersonを入れ替える
  def self.transform_prefs(prefs)
    result = {}
    prefs.each do |person, items|
      items.each do |item, value|
        result[item] ||= {}
        # itemとpersonを入れ替える
        result[item][person]=prefs[person][item]
      end
    end
    result
  end

  # ディクショナリrefsからpersonにもっともマッチするものたちを返す
  # 結果の数と類似性関数はオプションのパラメータ
  def self.top_matches(prefs, person, params={})
    n = params[:n] ? params[:n] : 5 # 結果の数
    similarity = params[:similarity] ? params[:similarity] : :sim_pearson # 類似性関数
    other_prefs = prefs.reject{|other, items| other==person}
    scores = other_prefs.map do |other, items|
      [self.send(similarity, prefs, person, other), other]
    end
    #高スコアがリストの最初に来るように並び替える
    scores.sort!
    scores.reverse!

    scores[0, n]
  end

  # p1とp2の距離を基にした類似性スコアを返す
  def self.sim_distance(prefs, p1, p2)
    return 0 if prefs[p1].nil?
    si = {}

    # 二人とも評価しているアイテムのリストを得る
    prefs[p1].each do |item, value|
      si[item]=1 if prefs[p2][item]
    end

    # 両者共に評価しているアイテムのリストを得る
    return 0 if si.size == 0

    # すべての差の平方を足し合わせる
    sum_of_squares = prefs[p1].inject(0) do |total, (item,value)|
      prefs[p2][item] ? total + (prefs[p1][item] - prefs[p2][item])**2 : total
    end
    sum_of_squares ? 1/(1+sum_of_squares) : 0
  end


  # p1とp2のピアソン相関係数を返す
  def self.sim_pearson(prefs, p1, p2)
    return 0 if prefs[p1].nil?

    # 両者が互いに評価しているアイテムのリストを取得
    si = {}
    prefs[p1].each do |item, value|
      si[item]=1 if prefs[p2] && prefs[p2][item]
    end

    # 要素の数を調べる
    n = si.size

    # 共に評価しているアイテムがなければ0を返す
    return 0 if n==0

    # すべての嗜好を計算する
    sum1 = si.inject(0){ |total, (item, value)| total + prefs[p1][item] }
    sum2 = si.inject(0){ |total, (item, value)| total + prefs[p2][item] }

    # 平方を合計する
    sum1Sq = si.inject(0){ |total, (item, value)| total + prefs[p1][item]**2 }
    sum2Sq = si.inject(0){ |total, (item, value)| total + prefs[p2][item]**2 }

    # 積を合計する
    pSum = si.inject(0){ |total, (item,value)| total + prefs[p1][item]*prefs[p2][item] }

    # ピアソンによるスコアを計算する
    num = pSum-(sum1*sum2/n)
    den = Math.sqrt((sum1Sq-sum1**2/n)*(sum2Sq-sum2**2/n))
    return 0 if den == 0

    num/den
  end

  # p1とp2のタニモト係数を返す
  def self.sim_tanimoto(prefs, p1, p2)
    # 両者が互いに評価しているアイテムのリストを取得
    c = prefs[p1].keys & prefs[p2].keys

    return 0.0 if c.empty?

    na = prefs[p1].length.to_f
    nb = prefs[p2].length.to_f
    nc = c.length.to_f

    nc / (na + nb - nc)
  end

end

